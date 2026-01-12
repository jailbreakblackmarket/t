crontab -r 2>/dev/null; crontab - <<'EOF'
*/12 * * * * SPORT_ID="323" DB_PATH="/root/betby_collector/betby.sqlite3" /usr/bin/python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1
EOF

sqlite3 -json /root/betby_collector/betby.sqlite3 \
"SELECT event_id, event_json FROM events;" > /home/rebsijo/events_dump.json
chown -R rebsijo:rebsijo /home/rebsijo/events_dump.json
grep -E 'added_count=[0-2]\b' /root/betby_collector/collector.log
sqlite3 /root/betby_collector/betby.sqlite3 "SELECT COUNT(*) FROM events;"
