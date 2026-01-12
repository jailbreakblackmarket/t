tail -n 50 /root/betby_collector/collector.log
sqlite3 /root/betby_collector/betby.sqlite3 ".tables"
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_id, first_seen_ts_utc FROM events LIMIT 15;"
