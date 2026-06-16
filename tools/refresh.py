#!/usr/bin/env python3
"""
Orbit Wars dashboard refresh.
Usage: python3 tools/refresh.py --team theburroship
"""
import csv, io, json, os, subprocess, sys
from datetime import datetime, timezone

COMP = "orbit-wars"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "netlify", "data.json")

TEAM = None
if "--team" in sys.argv:
    i = sys.argv.index("--team")
    if i + 1 < len(sys.argv):
        TEAM = sys.argv[i + 1]

def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout
    except Exception as e:
        print(f"  command failed: {' '.join(cmd)}  ({e})")
        return ""

def parse_csv(text):
    if not text.strip(): return []
    return [dict(r) for r in csv.DictReader(io.StringIO(text))]

def main():
    print("Pulling submissions...")
    submissions = parse_csv(run(["kaggle", "competitions", "submissions", COMP, "-v"]))
    print("Pulling leaderboard...")
    leaderboard = parse_csv(run(["kaggle", "competitions", "leaderboard", COMP, "-s", "-v"]))
    my_rank = my_score = None
    if TEAM:
        for idx, row in enumerate(leaderboard, start=1):
            name = (row.get("teamName") or row.get("teamNameNullable") or "").strip()
            if name.lower() == TEAM.lower():
                my_rank = idx; my_score = row.get("score"); break
    data = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "competition": COMP, "team": TEAM,
        "my_rank": my_rank, "my_score": my_score,
        "leaderboard_size": len(leaderboard),
        "submissions": submissions,
        "leaderboard_top": leaderboard[:25],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(data, f, indent=2)
    print(f"\nWrote {OUT}")
    print(f"  submissions: {len(submissions)}  leaderboard rows: {len(leaderboard)}")
    if my_rank:
        print(f"  {TEAM} rank: {my_rank} of {len(leaderboard)}  score {my_score}")
    print(f"\nOpen: open {os.path.join(ROOT, 'dashboard', 'index.html')}")

if __name__ == "__main__":
    main()
