sudo -i && \
set -euo pipefail && \
PYFILE="/root/betby_collector/collector.py" && \
DB="/root/betby_collector/betby.sqlite3" && \
LOG="/root/betby_collector/collector.log" && \
mkdir -p /root/betby_collector && \
touch "$LOG" && \
python3 -m pip install -q --upgrade pip >/dev/null && \
python3 -m pip install -q requests >/dev/null && \
python3 - <<'PY'
import sqlite3, os
db="/root/betby_collector/betby.sqlite3"
if not os.path.exists(db):
    print("DB does not exist yet, nothing to migrate.")
    raise SystemExit(0)

conn=sqlite3.connect(db)
try:
    conn.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts_utc TEXT NOT NULL,
            version INTEGER NOT NULL,
            sport_id TEXT NOT NULL,
            matched_event_count INTEGER NOT NULL
        )
    """)
    cols = {r[1] for r in conn.execute("PRAGMA table_info(runs)").fetchall()}
    if "stored_new_or_changed_count" not in cols:
        conn.execute("ALTER TABLE runs ADD COLUMN stored_new_or_changed_count INTEGER NOT NULL DEFAULT 0")
        conn.commit()
        print("✅ Migrated runs table: added stored_new_or_changed_count")
    else:
        print("✅ runs table already has stored_new_or_changed_count")
finally:
    conn.close()
PY
python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1 || true && \
python3 /root/betby_collector/collector.py --install-cron && \
apt update -y >/dev/null && apt install -y cron >/dev/null && \
systemctl enable --now cron >/dev/null && \
crontab -l && \
echo "✅ Fixed. DB: /root/betby_collector/betby.sqlite3  LOG: /root/betby_collector/collector.log" && \
tail -n 30 /root/betby_collector/collector.log || true
