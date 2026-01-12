crontab -l
tail -n 50 /root/betby_collector/collector.log
sqlite3 /root/betby_collector/betby.sqlite3 "select * from runs order by id desc limit 5;"
