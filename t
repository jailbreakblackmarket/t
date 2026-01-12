
sqlite3 /root/betby_collector/betby.sqlite3 "PRAGMA table_info(events);"
sleep 5
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_id, last_seen_ts_utc, last_seen_version
 FROM events
 ORDER BY last_seen_ts_utc DESC
 LIMIT 10;"
sleep 5
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_id, last_seen_ts_utc, last_seen_version
 FROM events
 ORDER BY last_seen_ts_utc DESC
 LIMIT 10;"
