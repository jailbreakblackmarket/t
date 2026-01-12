
set -euo pipefail && \
echo "== whoami ==" && whoami && \
echo "== python ==" && python3 --version && \
echo "== requests installed? ==" && python3 - <<'PY'
import requests
print("OK: requests", requests.__version__)
PY
echo "== files exist? ==" && \
ls -lah /root/betby_collector/collector.py && \
touch /root/betby_collector/collector.log && \
echo "== cron service status ==" && \
systemctl is-enabled cron && systemctl is-active cron && \
echo "== root crontab ==" && \
(crontab -l || true) && \
echo "== run collector once (writes to log) ==" && \
SPORT_ID="323" DB_PATH="/root/betby_collector/betby.sqlite3" LOG_PATH="/root/betby_collector/collector.log" TIMEOUT_SECONDS="25" \
python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1 && \
echo "== last lines of log ==" && \
tail -n 30 /root/betby_collector/collector.log && \
echo "== sqlite tables ==" && \
sqlite3 /root/betby_collector/betby.sqlite3 ".tables" && \
echo "== runs schema ==" && \
sqlite3 /root/betby_collector/betby.sqlite3 "pragma table_info(runs);" && \
echo "== last 5 runs ==" && \
sqlite3 /root/betby_collector/betby.sqlite3 "select id, ts_utc, version, sport_id, matched_event_count, stored_new_or_changed_count from runs order by id desc limit 5;" && \
echo "== latest events count ==" && \
sqlite3 /root/betby_collector/betby.sqlite3 "select count(*) as events_latest_count from events_latest;" && \
echo "== history rows count ==" && \
sqlite3 /root/betby_collector/betby.sqlite3 "select count(*) as events_history_count from events_history;" && \
echo "✅ ALL CHECKS PASSED"
