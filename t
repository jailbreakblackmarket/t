set -euo pipefail; \
DB="/root/betby_collector/betby.sqlite3"; PYF="/root/betby_collector/collector.py"; LOG="/root/betby_collector/collector.log"; \
echo "== 1) check files =="; ls -lah /root/betby_collector; \
echo; echo "== 2) show betby cron block =="; crontab -l | sed -n '/# betby-collector BEGIN/,/# betby-collector END/p'; \
echo; echo "== 3) verify DB schema (runs table) =="; sqlite3 "$DB" "PRAGMA table_info(runs);"; \
echo; echo "== 4) run collector once now (append to log) =="; \
SPORT_ID="323" DB_PATH="$DB" LOG_PATH="$LOG" TIMEOUT_SECONDS="25" /usr/bin/python3 "$PYF" >>"$LOG" 2>&1 || (echo "❌ collector failed - last 80 log lines:"; tail -n 80 "$LOG"; exit 1); \
echo "✅ collector ran successfully"; \
echo; echo "== 5) show latest run row =="; \
sqlite3 "$DB" "SELECT id, ts_utc, version, sport_id, matched_event_count, COALESCE(stored_new_or_changed_count,'(missing)') FROM runs ORDER BY id DESC LIMIT 1;"; \
echo; echo "== 6) confirm cron daemon + next scheduled runs =="; \
(systemctl is-active cron && systemctl status cron --no-pager -n 3) || true; \
echo; echo "== 7) last 40 log lines =="; tail -n 40 "$LOG"; \
echo; echo "✅ If step 4 succeeded and step 5 shows a new row, everything is working."
