sqlite3 -json /root/betby_collector/betby.sqlite3 \
"SELECT event_id, event_json FROM events;" > /home/rebsijo/events_dump.json
chown -R rebsijo:rebsijo /home/rebsijo/events_dump.json
grep -E 'added_count=[0-3]\b' /root/betby_collector/collector.log
sqlite3 /root/betby_collector/betby.sqlite3 "SELECT COUNT(*) FROM events;"
curl "https://discord.com/api/v10/guilds/1429069548086235210/channels" \
  -H "Authorization: MjkxNTk1NzM1MTE4NTEyMTI5.Gk_jhz.KI3t7XKO3PNqa8LV_iHW-zCAJ0_MAPC_JLt_Bk"
