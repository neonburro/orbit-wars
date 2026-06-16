import argparse
import datetime
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "netlify", "data.json")
COMP = "orbit-wars"


def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return r.stdout, r.stderr, r.returncode
    except Exception as e:
        return "", str(e), 1


def parse_table(text):
    lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
    lines = [ln for ln in lines if not ln.startswith("Next Page Token")
             and "Warning" not in ln and "Authentication" not in ln]
    header_idx = None
    for i, ln in enumerate(lines):
        if i + 1 < len(lines) and set(lines[i + 1].strip()) <= set("- "):
            header_idx = i
            break
    if header_idx is None:
        return [], []
    headers = re.split(r"\s{2,}", lines[header_idx].strip())
    rows = []
    for ln in lines[header_idx + 2:]:
        cells = re.split(r"\s{2,}", ln.strip())
        if len(cells) >= 2:
            rows.append(cells)
    return headers, rows


def get_submissions():
    out, err, code = run(["kaggle", "competitions", "submissions", COMP, "-v"])
    if code == 0 and "," in out:
        lines = [l for l in out.splitlines() if l.strip()
                 and not l.startswith("Warning") and "Authentication" not in l]
        if len(lines) >= 1:
            hdr = [h.strip().strip('"') for h in lines[0].split(",")]
            subs = []
            for ln in lines[1:]:
                parts = [p.strip().strip('"') for p in ln.split(",")]
                row = dict(zip(hdr, parts))
                subs.append({
                    "ref": row.get("ref") or row.get("fileName") or "",
                    "fileName": row.get("fileName", ""),
                    "description": row.get("description", ""),
                    "date": row.get("date", ""),
                    "publicScore": row.get("publicScore") or row.get("score") or "",
                    "status": row.get("status", ""),
                })
            return subs
    out, err, code = run(["kaggle", "competitions", "submissions", COMP])
    headers, rows = parse_table(out)
    subs = []
    for r in rows:
        d = dict(zip(headers, r))
        subs.append({
            "ref": d.get("ref") or d.get("fileName") or "",
            "fileName": d.get("fileName", ""),
            "description": d.get("description", ""),
            "date": d.get("date", ""),
            "publicScore": d.get("publicScore") or d.get("score") or "",
            "status": d.get("status", ""),
        })
    return subs


def get_leaderboard(team):
    out, err, code = run(["kaggle", "competitions", "leaderboard", COMP, "--show"])
    headers, rows = parse_table(out)
    top = []
    my_rank = None
    my_score = None
    for i, r in enumerate(rows):
        d = dict(zip(headers, r))
        name = d.get("teamName") or d.get("team") or ""
        score = d.get("score") or ""
        sub_date = d.get("submissionDate") or ""
        top.append({"teamName": name, "score": score, "submissionDate": sub_date})
        if team and name.strip().lower() == team.strip().lower():
            my_rank = i + 1
            my_score = score
    return top, my_rank, my_score


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--team", default="theburroship")
    args = ap.parse_args()
    print("Pulling submissions...")
    subs = get_submissions()
    print("Pulling leaderboard...")
    top, my_rank, my_score = get_leaderboard(args.team)
    data = {
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "competition": COMP,
        "team": args.team,
        "my_rank": my_rank,
        "my_score": my_score,
        "leaderboard_size": len(top),
        "submissions": subs,
        "leaderboard_top": top,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(data, f, indent=2)
    print("Wrote %s" % OUT)
    print("  submissions: %d  leaderboard rows: %d  my_rank: %s  my_score: %s"
          % (len(subs), len(top), my_rank, my_score))


if __name__ == "__main__":
    main()
