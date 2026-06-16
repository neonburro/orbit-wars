import json
import os
import random
import subprocess
import sys
import contextlib
import io

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OPPONENT = os.path.join(ROOT, "v2.py")
MAKER = os.path.join(ROOT, "make_candidate.py")
BEST_JSON = os.path.join(HERE, "best_params.json")
TRAINED = os.path.join(ROOT, "main_trained.py")

SPACE = {
    "reserve_ratio": (0.05, 0.35),
    "reserve_ratio_late": (0.15, 0.45),
    "leader_bonus": (0.0, 2.0),
    "enemy_bonus": (0.0, 1.2),
    "comet_bonus": (0.0, 1.5),
    "prod_weight": (0.5, 2.5),
    "inbound_thresh": (0.5, 0.97),
    "overshoot": (1, 4),
}


def sample():
    p = {}
    for k, (lo, hi) in SPACE.items():
        if k == "overshoot":
            p[k] = random.randint(int(lo), int(hi))
        else:
            p[k] = round(random.uniform(lo, hi), 3)
    return p


def make_candidate(params, path):
    subprocess.run(["python3", MAKER, json.dumps(params), path], check=True, capture_output=True)


def win_rate(cand_path, n_seeds, max_steps=250):
    from kaggle_environments import make
    wins = total = 0
    with contextlib.redirect_stderr(io.StringIO()):
        for seed in range(n_seeds):
            for order in (0, 1):
                env = make("orbit_wars", configuration={"seed": seed, "episodeSteps": max_steps}, debug=False)
                if order == 0:
                    env.run([cand_path, OPPONENT])
                    r = env.steps[-1]
                    cand_r, opp_r = r[0]["reward"], r[1]["reward"]
                else:
                    env.run([OPPONENT, cand_path])
                    r = env.steps[-1]
                    opp_r, cand_r = r[0]["reward"], r[1]["reward"]
                total += 1
                if cand_r > opp_r:
                    wins += 1
    return wins / total if total else 0.0


def main():
    n_cand = int(sys.argv[1]) if len(sys.argv) > 1 else 16
    n_seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    cand_path = os.path.join(ROOT, "_cand.py")
    best = None
    best_rate = -1.0
    print("Training: %d candidates x %d games each vs v2\n" % (n_cand, n_seeds * 2))
    for i in range(n_cand):
        params = sample()
        make_candidate(params, cand_path)
        rate = win_rate(cand_path, n_seeds)
        flag = ""
        if rate > best_rate:
            best_rate = rate
            best = params
            flag = "  <-- new best"
        print("  cand %2d: win %3.0f%%%s" % (i + 1, rate * 100, flag))
    print("\nBest win rate vs v2: %.0f%%" % (best_rate * 100))
    print("Best params:")
    print(json.dumps(best, indent=2))
    with open(BEST_JSON, "w") as f:
        json.dump({"win_rate_vs_v2": best_rate, "params": best}, f, indent=2)
    make_candidate(best, TRAINED)
    print("\nSaved best config to %s" % BEST_JSON)
    print("Wrote winning bot to %s" % TRAINED)
    if best_rate >= 0.6:
        print("\nThis beats v2 cleanly. Validate, then:")
        print("  cp main_trained.py main.py")
        print('  kaggle competitions submit orbit-wars -f main.py -m "trained bot"')
    else:
        print("\nNot a clean win over v2 yet. Run more candidates or widen the search.")
    if os.path.exists(cand_path):
        os.remove(cand_path)


if __name__ == "__main__":
    main()
