sudo -i && \
set -uo pipefail && \
echo "== whoami ==" && whoami && \
echo "== python ==" && python3 --version && \
echo "== quick network check ==" && \
curl -sS -I --max-time 10 "https://demoapi.betby.com/api/v4/prematch/brand/1653815133341880320/en/0" | head -n 5 && \
echo "== ensure log/db paths ==" && \
mkdir -p /root/betby_collector && \
touch /root/betby_collector/collector.log && \
echo "== root crontab ==" && (crontab -l || true) && \
echo "== run collector once (timeout 90s) ==" && \
set +e && \
SPORT_ID="323" DB_PATH="/root/betby_collector/betby.sqlite3" LOG_PATH="/root/betby_collector/collector.log" TIMEOUT_SECONDS="25" \
timeout 90s /usr/bin/python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1
RC=$?
set -e && \
echo "collector exit code: $RC (0=OK, 124=timeout)" && \
echo "== last 80 lines of log ==" && tail -n 80 /root/betby_collector/collector.log || true && \
echo "== DB checks (if DB exists) ==" && \
if [ -f /root/betby_collector/betby.sqlite3 ]; then \
  sqlite3 /root/betby_collector/betby.sqlite3 "pragma table_info(runs);" && \
  sqlite3 /root/betby_collector/betby.sqlite3 "select id, ts_utc, version, sport_id, matched_event_count, stored_new_or_changed_count from runs order by id desc limit 5;"; \
else \
  echo "DB not found: /root/betby_collector/betby.sqlite3"; \
fi && \
echo "✅ Test finished"
