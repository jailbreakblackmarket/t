#!/usr/bin/env bash
set -euo pipefail

# --- Figure out which user/home to install under ---
if [[ "${EUID}" -eq 0 ]]; then
  # If someone runs as root, try to install for the original user
  TARGET_USER="${SUDO_USER:-root}"
else
  TARGET_USER="${USER}"
fi

HOME_DIR="$(eval echo "~${TARGET_USER}")"
APP_DIR="${HOME_DIR}/betby_collector"
VENV_DIR="${APP_DIR}/.venv"
PY="${VENV_DIR}/bin/python"

SERVICE_PATH="/etc/systemd/system/betby-collector.service"
TIMER_PATH="/etc/systemd/system/betby-collector.timer"

echo "Installing for user: ${TARGET_USER}"
echo "Home directory: ${HOME_DIR}"
echo "App directory: ${APP_DIR}"
echo

# --- System deps ---
echo "==> Installing system packages..."
sudo apt update -y
sudo apt install -y python3 python3-venv sqlite3

# --- Create app directory ---
echo "==> Creating app directory..."
mkdir -p "${APP_DIR}"

# If run as root, ensure ownership
if [[ "${EUID}" -eq 0 && "${TARGET_USER}" != "root" ]]; then
  chown -R "${TARGET_USER}:${TARGET_USER}" "${APP_DIR}"
fi

# --- Create venv + install python deps ---
echo "==> Creating Python venv and installing dependencies..."
if [[ ! -d "${VENV_DIR}" ]]; then
  sudo -u "${TARGET_USER}" python3 -m venv "${VENV_DIR}"
fi
sudo -u "${TARGET_USER}" "${PY}" -m pip install --upgrade pip >/dev/null
sudo -u "${TARGET_USER}" "${PY}" -m pip install requests >/dev/null

# --- Write collector.py ---
echo "==> Writing collector.py..."
cat > "${APP_DIR}/collector.py" <<'PYCODE'
#!/usr/bin/env python3
import os
import json
import time
import sqlite3
import requests
from datetime import datetime, timezone

BASE_URL = "https://demoapi.betby.com/api/v4/prematch/brand/1653815133341880320/en"
SPORT_ID = os.environ.get("SPORT_ID", "323")
DB_PATH = os.environ.get("DB_PATH", "./betby.sqlite3")
TIMEOUT_SECONDS = int(os.environ.get("TIMEOUT_SECONDS", "25"))

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def fetch_json(session: requests.Session, url: str, tries: int = 3):
    last_err = None
    for attempt in range(1, tries + 1):
        try:
            r = session.get(url, timeout=TIMEOUT_SECONDS)
            r.raise_for_status()
            return r.json()
        except Exception as e:
            last_err = e
            time.sleep(1.5 * attempt)
    raise RuntimeError(f"Failed to fetch after {tries} tries: {url} ({last_err})")

def init_db(conn: sqlite3.Connection):
    conn.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts_utc TEXT NOT NULL,
            version INTEGER NOT NULL,
            sport_id TEXT NOT NULL,
            matched_event_count INTEGER NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events (
            event_id TEXT PRIMARY KEY,
            sport_id TEXT NOT NULL,
            first_seen_ts_utc TEXT NOT NULL,
            last_seen_ts_utc TEXT NOT NULL,
            last_seen_version INTEGER NOT NULL
        )
    """)
    conn.commit()

def upsert_events(conn: sqlite3.Connection, event_ids: list[str], sport_id: str, ts: str, version: int):
    for eid in event_ids:
        conn.execute("""
            INSERT INTO events (event_id, sport_id, first_seen_ts_utc, last_seen_ts_utc, last_seen_version)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(event_id) DO UPDATE SET
                last_seen_ts_utc = excluded.last_seen_ts_utc,
                last_seen_version = excluded.last_seen_version
        """, (eid, sport_id, ts, ts, version))
    conn.commit()

def main():
    ts = utc_now_iso()

    with requests.Session() as session:
        # 1) get version from /en/0
        v0_url = f"{BASE_URL}/0"
        v0 = fetch_json(session, v0_url)
        version = int(v0["version"])

        # 2) fetch snapshot from /en/<version>
        version_url = f"{BASE_URL}/{version}"
        data = fetch_json(session, version_url)

    events = data.get("events", {}) or {}
    matched_ids = []
    for event_id, payload in events.items():
        desc = (payload or {}).get("desc", {}) or {}
        if str(desc.get("sport")) == str(SPORT_ID):
            matched_ids.append(str(event_id))

    conn = sqlite3.connect(DB_PATH)
    try:
        init_db(conn)
        conn.execute(
            "INSERT INTO runs (ts_utc, version, sport_id, matched_event_count) VALUES (?, ?, ?, ?)",
            (ts, version, str(SPORT_ID), len(matched_ids)),
        )
        upsert_events(conn, matched_ids, str(SPORT_ID), ts, version)
    finally:
        conn.close()

    print(json.dumps({
        "ts_utc": ts,
        "version": version,
        "sport_id": str(SPORT_ID),
        "matched_event_count": len(matched_ids),
    }, ensure_ascii=False))

if __name__ == "__main__":
    main()
PYCODE

chmod +x "${APP_DIR}/collector.py"

# --- Ensure ownership of app files ---
if [[ "${EUID}" -eq 0 && "${TARGET_USER}" != "root" ]]; then
  chown -R "${TARGET_USER}:${TARGET_USER}" "${APP_DIR}"
fi

# --- Write systemd service ---
echo "==> Creating systemd service..."
sudo tee "${SERVICE_PATH}" >/dev/null <<EOF
[Unit]
Description=Betby collector (fetch version + sport 323 event ids)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${TARGET_USER}
WorkingDirectory=${APP_DIR}
Environment=SPORT_ID=323
Environment=DB_PATH=${APP_DIR}/betby.sqlite3
Environment=TIMEOUT_SECONDS=25
ExecStart=${PY} ${APP_DIR}/collector.py
EOF

# --- Write systemd timer (every 18 minutes) ---
echo "==> Creating systemd timer..."
sudo tee "${TIMER_PATH}" >/dev/null <<'EOF'
[Unit]
Description=Run Betby collector every 18 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=18min
Unit=betby-collector.service
Persistent=true

[Install]
WantedBy=timers.target
EOF

# --- Enable and start ---
echo "==> Enabling timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now betby-collector.timer

echo
echo "✅ Done!"
echo
echo "Check next runs:"
echo "  systemctl list-timers --all | grep betby"
echo
echo "See latest service logs:"
echo "  journalctl -u betby-collector.service -n 100 --no-pager"
echo
echo "Check stored data:"
echo "  sqlite3 ${APP_DIR}/betby.sqlite3 \"select * from runs order by id desc limit 5;\""
echo "  sqlite3 ${APP_DIR}/betby.sqlite3 \"select event_id, last_seen_ts_utc, last_seen_version from events order by last_seen_ts_utc desc limit 20;\""
