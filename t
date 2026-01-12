sudo -i && \
set -euo pipefail && \
DB="/root/betby_collector/betby.sqlite3" && \
LOG="/root/betby_collector/collector.log" && \
echo "== stopping cron (temporary) ==" && (systemctl stop cron || true) && \
echo "== migrating DB (add missing column if needed) ==" && \
python3 - <<'PY'
import sqlite3, os
db="/root/betby_collector/betby.sqlite3"
if not os.path.exists(db):
    raise SystemExit(f"DB not found: {db}")

conn = sqlite3.connect(db)
try:
    # Make sure runs table exists (doesn't change existing if already there)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts_utc TEXT NOT NULL,
            version INTEGER NOT NULL,
            sport_id TEXT NOT NULL,
            matched_event_count INTEGER NOT NULL
        )
    """)
    cols = [r[1] for r in conn.execute("PRAGMA table_info(runs)").fetchall()]
    if "stored_new_or_changed_count" not in cols:
        conn.execute("ALTER TABLE runs ADD COLUMN stored_new_or_changed_count INTEGER NOT NULL DEFAULT 0")
        conn.commit()
        print("✅ Added column: stored_new_or_changed_count")
    else:
        print("✅ Column already present: stored_new_or_changed_count")
finally:
    conn.close()
PY
echo "== verify runs schema ==" && \
sqlite3 "$DB" "pragma table_info(runs);" && \
echo "== run collector once ==" && \
touch "$LOG" && \
SPORT_ID="323" DB_PATH="$DB" LOG_PATH="$LOG" TIMEOUT_SECONDS="25" \
/usr/bin/python3 /root/betby_collector/collector.py >> "$LOG" 2>&1 && \
echo "== last 5 runs ==" && \
sqlite3 "$DB" "select id, ts_utc, version, sport_id, matched_event_count, stored_new_or_changed_count from runs order by id desc limit 5;" && \
echo "== starting cron back ==" && (systemctl start cron || true) && \
echo "== last 40 log lines ==" && tail -n 40 "$LOG"
