
DB="/root/betby_collector/betby.sqlite3" && \
PYF="/root/betby_collector/collector.py" && \
LOG="/root/betby_collector/collector.log" && \
echo "== stop cron ==" && (systemctl stop cron || true) && \
echo "== ensure paths ==" && mkdir -p /root/betby_collector && touch "$LOG" && \
echo "== migrate DB schema (add column if missing) ==" && \
python3 - <<'PY'
import sqlite3, os
db="/root/betby_collector/betby.sqlite3"
conn=sqlite3.connect(db)
try:
    conn.execute("""CREATE TABLE IF NOT EXISTS runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts_utc TEXT NOT NULL,
        version INTEGER NOT NULL,
        sport_id TEXT NOT NULL,
        matched_event_count INTEGER NOT NULL
    )""")
    cols=[r[1] for r in conn.execute("PRAGMA table_info(runs)").fetchall()]
    if "stored_new_or_changed_count" not in cols:
        conn.execute("ALTER TABLE runs ADD COLUMN stored_new_or_changed_count INTEGER NOT NULL DEFAULT 0")
        conn.commit()
        print("✅ DB migrated: added stored_new_or_changed_count")
    else:
        print("✅ DB already has stored_new_or_changed_count")
finally:
    conn.close()
PY
echo "== patch collector.py to auto-migrate (so it never breaks again) ==" && \
python3 - <<'PY'
import os, re
path="/root/betby_collector/collector.py"
txt=open(path,"r",encoding="utf-8").read()

# Find init_db() block
m=re.search(r"(def init_db\([^\)]*\):\n)([\s\S]*?)(\n(?=def |\Z))", txt)
if not m:
    raise SystemExit("Could not find init_db() in collector.py")

head, body, tail = m.group(1), m.group(2), m.group(3)

snippet = """
    # --- auto-migrate older DBs (runs table new column) ---
    try:
        cols = [r[1] for r in conn.execute("PRAGMA table_info(runs)").fetchall()]
        if "stored_new_or_changed_count" not in cols:
            conn.execute("ALTER TABLE runs ADD COLUMN stored_new_or_changed_count INTEGER NOT NULL DEFAULT 0")
    except Exception:
        # If migration fails for any reason, let normal DB ops raise later
        pass
"""

if "stored_new_or_changed_count" not in body:
    # insert snippet right before the first conn.commit() inside init_db
    if "conn.commit()" in body:
        body = body.replace("    conn.commit()", snippet + "\n    conn.commit()", 1)
    else:
        # if no commit found, append snippet
        body = body + "\n" + snippet

new_txt = txt[:m.start()] + head + body + tail + txt[m.end():]
open(path,"w",encoding="utf-8").write(new_txt)
print("✅ collector.py patched (init_db now auto-migrates)")
PY
echo "== verify schema ==" && sqlite3 "$DB" "pragma table_info(runs);" && \
echo "== run collector once (should be NO traceback) ==" && \
SPORT_ID="323" DB_PATH="$DB" LOG_PATH="$LOG" TIMEOUT_SECONDS="25" \
python3 "$PYF" >> "$LOG" 2>&1 && \
echo "== last 3 runs ==" && \
sqlite3 "$DB" "select id, ts_utc, version, sport_id, matched_event_count, stored_new_or_changed_count from runs order by id desc limit 3;" && \
echo "== start cron ==" && (systemctl start cron || true) && \
echo "✅ Fixed. Last log lines:" && tail -n 30 "$LOG"
