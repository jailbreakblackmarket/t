EVENT_ID="2622424405195755521"
sqlite3 /root/betby_collector/betby.sqlite3 "SELECT json FROM event_objects WHERE event_id='$EVENT_ID';" \
| python3 -m json.tool
