sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT id, ts_utc, version, sport_id, matched_event_count, stored_new_or_changed_count
 FROM runs
 ORDER BY id DESC
 LIMIT 20;"
sleep 5
sqlite3 /root/betby_collector/betby.sqlite3 ".tables"
sleep 5
sqlite3 /root/betby_collector/betby.sqlite3 "PRAGMA table_info(event_objects);"
sleep 5
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_id, last_seen_ts_utc, last_seen_version
 FROM event_objects
 ORDER BY last_seen_ts_utc DESC
 LIMIT 10;"
sleep 5
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_id, last_seen_ts_utc, last_seen_version
 FROM event_objects
 ORDER BY last_seen_ts_utc DESC
 LIMIT 10;"
