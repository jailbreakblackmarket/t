tail -n 50 /root/betby_collector/collector.log
sqlite3 /root/betby_collector/betby.sqlite3 ".tables"
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_id, first_seen_ts_utc FROM events LIMIT 15;"
EVENT_ID="2622480341859962890"
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_json FROM events WHERE event_id='$EVENT_ID';" | python3 -m json.tool
