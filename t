DB="/root/betby_collector/betby.sqlite3"; \
echo "== events table columns =="; sqlite3 "$DB" "PRAGMA table_info(events);"; \
echo; echo "== example row (latest) =="; sqlite3 -header -column "$DB" "SELECT * FROM events ORDER BY last_seen_ts_utc DESC LIMIT 1;"
