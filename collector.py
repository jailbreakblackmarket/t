#!/usr/bin/env python3
import os
import json
import time
import sqlite3
from pathlib import Path
from datetime import datetime, timezone

import requests

# --- Config ---
BASE_URL = "https://demoapi.betby.com/api/v4/prematch/brand/1653815133341880320/en"
SPORT_ID = os.environ.get("SPORT_ID", "323")
TIMEOUT_SECONDS = int(os.environ.get("TIMEOUT_SECONDS", "25"))

SCRIPT_DIR = Path(__file__).resolve().parent
DB_PATH = os.environ.get("DB_PATH", str(SCRIPT_DIR / "betby.sqlite3"))

# Headers from your HAR (keep it simple: only headers, no cookies)
HAR_HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0",
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.5",
    "Accept-Encoding": "gzip, deflate, br, zstd",
    "Referer": "https://demo.betby.com/",
    "Origin": "https://demo.betby.com",
    "Connection": "keep-alive",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-site",
    "Priority": "u=4",
    "TE": "trailers",
}

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def fetch_json(session: requests.Session, url: str, tries: int = 3):
    last_err = None
    for attempt in range(1, tries + 1):
        try:
            r = session.get(url, timeout=TIMEOUT_SECONDS)
            r.raise_for_status()
            return r.json()
        except Exception as e:
            last_err = e
            time.sleep(1.5 * attempt)
    raise RuntimeError(f"Failed to fetch after {tries} tries: {url} ({last_err})")

def init_db(conn: sqlite3.Connection):
    # runs: only timestamp + how many NEW events were added on this run
    conn.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts_utc TEXT NOT NULL,
            added_count INTEGER NOT NULL
        )
    """)
    # events: store each event once (dedup by event_id)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events (
            event_id TEXT PRIMARY KEY,
            sport_id TEXT NOT NULL,
            first_seen_ts_utc TEXT NOT NULL,
            event_json TEXT NOT NULL
        )
    """)
    conn.commit()

def main():
    ts = utc_now_iso()
    added_count = 0

    with requests.Session() as session:
        session.headers.update(HAR_HEADERS)

        # 1) get version from /en/0 (we do NOT store it)
        v0 = fetch_json(session, f"{BASE_URL}/0")
        version = int(v0["version"])

        # 2) fetch events snapshot from /en/<version>
        data = fetch_json(session, f"{BASE_URL}/{version}")

    events = data.get("events", {}) or {}

    conn = sqlite3.connect(DB_PATH)
    try:
        init_db(conn)

        for event_id, payload in events.items():
            desc = (payload or {}).get("desc", {}) or {}
            if str(desc.get("sport")) != str(SPORT_ID):
                continue

            event_id = str(event_id)
            payload_str = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))

            # Insert only if event_id doesn't exist yet
            cur = conn.execute("""
                INSERT OR IGNORE INTO events (event_id, sport_id, first_seen_ts_utc, event_json)
                VALUES (?, ?, ?, ?)
            """, (event_id, str(SPORT_ID), ts, payload_str))

            if cur.rowcount == 1:
                added_count += 1

        conn.execute("INSERT INTO runs (ts_utc, added_count) VALUES (?, ?)", (ts, added_count))
        conn.commit()

    finally:
        conn.close()

    # Minimal output (useful for cron logs)
    print(f"{ts} | added_count={added_count} | db={DB_PATH}")

if __name__ == "__main__":
    main()
