mkdir -p /root/betby_collector && \
cat > /root/betby_collector/collector.py <<'PY'
#!/usr/bin/env python3
import os
import sys
import json
import time
import sqlite3
import hashlib
import subprocess
from pathlib import Path
import requests
from datetime import datetime, timezone

BASE_URL = "https://demoapi.betby.com/api/v4/prematch/brand/1653815133341880320/en"
SPORT_ID = os.environ.get("SPORT_ID", "323")
TIMEOUT_SECONDS = int(os.environ.get("TIMEOUT_SECONDS", "25"))

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
DEFAULT_DB_PATH = str(SCRIPT_DIR / "betby.sqlite3")
DEFAULT_LOG_PATH = str(SCRIPT_DIR / "collector.log")

DB_PATH = os.environ.get("DB_PATH", DEFAULT_DB_PATH)
LOG_PATH = os.environ.get("LOG_PATH", DEFAULT_LOG_PATH)

HAR_HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.5",
    "Referer": "https://demo.betby.com/",
    "Origin": "https://demo.betby.com",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-site",
    "Priority": "u=4",
    "TE": "trailers",
}

CRON_BEGIN = "# betby-collector BEGIN"
CRON_END = "# betby-collector END"

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def canonical_json(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

def sha256_hex(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()

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
            matched_event_count INTEGER NOT NULL,
            stored_new_or_changed_count INTEGER NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events_latest (
            event_id TEXT PRIMARY KEY,
            sport_id TEXT NOT NULL,
            first_seen_ts_utc TEXT NOT NULL,
            last_seen_ts_utc TEXT NOT NULL,
            last_seen_version INTEGER NOT NULL,
            event_hash TEXT NOT NULL,
            event_json TEXT NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id TEXT NOT NULL,
            sport_id TEXT NOT NULL,
            version INTEGER NOT NULL,
            ts_utc TEXT NOT NULL,
            event_hash TEXT NOT NULL,
            event_json TEXT NOT NULL,
            UNIQUE(event_id, event_hash)
        )
    """)
    conn.commit()

def collector_run():
    ts = utc_now_iso()

    with requests.Session() as session:
        session.headers.update(HAR_HEADERS)

        v0 = fetch_json(session, f"{BASE_URL}/0")
        version = int(v0["version"])

        data = fetch_json(session, f"{BASE_URL}/{version}")

    events = data.get("events", {}) or {}

    matched = 0
    stored_new_or_changed = 0

    conn = sqlite3.connect(DB_PATH)
    try:
        init_db(conn)

        for event_id, payload in events.items():
            desc = (payload or {}).get("desc", {}) or {}
            if str(desc.get("sport")) != str(SPORT_ID):
                continue

            matched += 1
            event_id = str(event_id)

            payload_str = canonical_json(payload)
            h = sha256_hex(payload_str)

            cur = conn.execute("""
                INSERT OR IGNORE INTO events_history (event_id, sport_id, version, ts_utc, event_hash, event_json)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (event_id, str(SPORT_ID), version, ts, h, payload_str))
            if cur.rowcount == 1:
                stored_new_or_changed += 1

            row = conn.execute("SELECT event_hash FROM events_latest WHERE event_id = ?", (event_id,)).fetchone()
            if row is None:
                conn.execute("""
                    INSERT INTO events_latest (
                        event_id, sport_id,
                        first_seen_ts_utc, last_seen_ts_utc,
                        last_seen_version, event_hash, event_json
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (event_id, str(SPORT_ID), ts, ts, version, h, payload_str))
            else:
                prev_hash = row[0]
                if prev_hash == h:
                    conn.execute("""
                        UPDATE events_latest
                        SET last_seen_ts_utc = ?, last_seen_version = ?
                        WHERE event_id = ?
                    """, (ts, version, event_id))
                else:
                    conn.execute("""
                        UPDATE events_latest
                        SET last_seen_ts_utc = ?, last_seen_version = ?, event_hash = ?, event_json = ?
                        WHERE event_id = ?
                    """, (ts, version, h, payload_str, event_id))

        conn.execute("""
            INSERT INTO runs (ts_utc, version, sport_id, matched_event_count, stored_new_or_changed_count)
            VALUES (?, ?, ?, ?, ?)
        """, (ts, version, str(SPORT_ID), matched, stored_new_or_changed))

        conn.commit()

    finally:
        conn.close()

    print(json.dumps({
        "ts_utc": ts,
        "version": version,
        "sport_id": str(SPORT_ID),
        "matched_event_count": matched,
        "stored_new_or_changed_count": stored_new_or_changed,
        "db_path": DB_PATH
    }, ensure_ascii=False))

def build_cron_block() -> str:
    python = sys.executable
    script = str(SCRIPT_PATH)
    env_prefix = (
        f'SPORT_ID="{SPORT_ID}" '
        f'DB_PATH="{DB_PATH}" '
        f'LOG_PATH="{LOG_PATH}" '
        f'TIMEOUT_SECONDS="{TIMEOUT_SECONDS}" '
    )
    cron_line = f'*/12 * * * * {env_prefix}{python} {script} >> "{LOG_PATH}" 2>&1'
    return "\n".join([CRON_BEGIN, cron_line, CRON_END]) + "\n"

def read_user_crontab() -> str:
    p = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
    if p.returncode == 0:
        return p.stdout
    if p.returncode == 1 and ("no crontab" in (p.stderr or "").lower() or p.stdout == ""):
        return ""
    raise RuntimeError(f"Failed to read crontab: {p.stderr.strip() or p.stdout.strip()}")

def write_user_crontab(content: str):
    p = subprocess.run(["crontab", "-"], input=content, text=True, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"Failed to write crontab: {p.stderr.strip()}")

def remove_existing_block(crontab_text: str) -> str:
    lines = crontab_text.splitlines()
    out = []
    in_block = False
    for line in lines:
        if line.strip() == CRON_BEGIN:
            in_block = True
            continue
        if in_block and line.strip() == CRON_END:
            in_block = False
            continue
        if not in_block:
            out.append(line)
    return ("\n".join(out).rstrip() + "\n") if out else ""

def install_cron():
    current = read_user_crontab()
    cleaned = remove_existing_block(current)
    block = build_cron_block()
    new_tab = cleaned + ("" if cleaned.endswith("\n") or cleaned == "" else "\n") + block
    write_user_crontab(new_tab)
    print("✅ Cron installed for this user (every 12 minutes).")
    print(f"Log file: {LOG_PATH}")
    print(f"DB file:  {DB_PATH}")

def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--install-cron":
        install_cron()
        return
    collector_run()

if __name__ == "__main__":
    main()
PY
chmod +x /root/betby_collector/collector.py && \
python3 -m pip install --upgrade pip >/dev/null && \
python3 -m pip install requests >/dev/null && \
python3 /root/betby_collector/collector.py && \
python3 /root/betby_collector/collector.py --install-cron && \
crontab -l && \
echo "✅ Done. Log: /root/betby_collector/collector.log  DB: /root/betby_collector/betby.sqlite3"
