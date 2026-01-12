echo "== stop cron ==" && (systemctl stop cron || true) && \
echo "== detect DB_PATH from root crontab ==" && \
CRON_BLOCK="$(crontab -l 2>/dev/null | sed -n '/# betby-collector BEGIN/,/# betby-collector END/p' || true)" && \
echo "$CRON_BLOCK" && \
DB_PATH="$(echo "$CRON_BLOCK" | sed -n 's/.*DB_PATH="\([^"]*\)".*/\1/p' | head -n 1)" && \
if [ -z "${DB_PATH}" ]; then DB_PATH="/root/betby_collector/betby.sqlite3"; fi && \
echo "Using DB_PATH: $DB_PATH" && \
mkdir -p /root/betby_collector && touch /root/betby_collector/collector.log && \
echo "== migrate DB (add stored_new_or_changed_count if missing) ==" && \
DB_PATH="$DB_PATH" python3 - <<'PY'
import os, sqlite3
db = os.environ["DB_PATH"]
conn = sqlite3.connect(db)
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
    cols = [r[1] for r in conn.execute("PRAGMA table_info(runs)").fetchall()]
    if "stored_new_or_changed_count" not in cols:
        conn.execute("ALTER TABLE runs ADD COLUMN stored_new_or_changed_count INTEGER NOT NULL DEFAULT 0")
        conn.commit()
        print("✅ Added column stored_new_or_changed_count to:", db)
    else:
        print("✅ Column already present in:", db)
finally:
    conn.close()
PY
echo "== verify schema ==" && \
sqlite3 "$DB_PATH" "pragma table_info(runs);" && \
echo "== run collector once (90s timeout) ==" && \
set +e && \
SPORT_ID="323" DB_PATH="$DB_PATH" LOG_PATH="/root/betby_collector/collector.log" TIMEOUT_SECONDS="25" \
timeout 90s /usr/bin/python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1
RC=$?
set -e && \
echo "collector exit code: $RC (0=OK, 124=timeout)" && \
echo "== last 5 runs (should include stored_new_or_changed_count) ==" && \
sqlite3 "$DB_PATH" "select id, ts_utc, version, sport_id, matched_event_count, stored_new_or_changed_count from runs order by id desc limit 5;" && \
echo "== start cron ==" && (systemctl start cron || true) && \
echo "== last 60 log lines ==" && tail -n 60 /root/betby_collector/collector.log
