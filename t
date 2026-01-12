tail -n 50 /root/betby_collector/collector.log
sqlite3 /root/betby_collector/betby.sqlite3 ".tables"
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_id, first_seen_ts_utc FROM events LIMIT 15;"
EVENT_ID="2622480341859962890"
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT event_json FROM events WHERE event_id='$EVENT_ID';" | python3 -m json.tool
sqlite3 /root/betby_collector/betby.sqlite3 "SELECT COUNT(*) FROM events;"
sqlite3 -json /root/betby_collector/betby.sqlite3 \
"SELECT event_id, event_json FROM events;" > /home/rebsijo/events_dump.json
chown -R rebsijo:rebsijo /home/rebsijo/events_dump.json
