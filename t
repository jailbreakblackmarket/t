crontab -r 2>/dev/null; crontab - <<'EOF'
0,18,36,54  */3 * * * /usr/bin/python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1
12,30,48    1-23/3 * * * /usr/bin/python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1
6,24,42     2-23/3 * * * /usr/bin/python3 /root/betby_collector/collector.py >> /root/betby_collector/collector.log 2>&1
EOF
