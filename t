crontab -l
ls -l /root/betby_collector
sqlite3 /root/betby_collector/betby.sqlite3 "SELECT COUNT(*) FROM events;"

