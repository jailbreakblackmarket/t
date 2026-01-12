
apt update -y && apt install -y cron >/dev/null && \
systemctl enable --now cron && \
touch /root/betby_collector/collector.log && \
python3 /root/betby_collector/collector.py --install-cron && \
crontab -l && \
echo "OK. Log: /root/betby_collector/collector.log"
SPORT_ID="323" DB_PATH="/root/betby_collector/betby.sqlite3" LOG_PATH="/root/betby_collector/collector.log" TIMEOUT_SECONDS="25" \
python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1
tail -n 50 /root/betby_collector/collector.log
systemctl status cron --no-pager
crontab -l
