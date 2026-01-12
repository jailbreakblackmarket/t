nano /root/betby_collector/collector.py
chmod +x /root/betby_collector/collector.py
python3 -m pip install --upgrade pip
python3 -m pip install requests
python3 /root/betby_collector/collector.py
python3 /root/betby_collector/collector.py --install-cron
crontab -l
tail -n 50 /root/betby_collector/collector.log
sqlite3 /root/betby_collector/betby.sqlite3 "select * from runs order by id desc limit 5;"
