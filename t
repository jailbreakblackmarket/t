

sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT id, ts_utc, added_count FROM runs ORDER BY id DESC LIMIT 5;"
sqlite3 /root/betby_collector/betby.sqlite3 \
"SELECT COUNT(*) FROM events;"
