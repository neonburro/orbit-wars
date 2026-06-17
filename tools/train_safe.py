import contextlib
import io
import json
import multiprocessing as mp
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MAKER = os.path.join(ROOT, "make_candidate.py")
BEST_JSON = os.path.join(HERE, "best_params.json")
TRAINED = os.path.join(ROOT, "main_trained.py")

OPPONENTS = [os.path.join(ROOT, f) for f in
             ["v2.py", "main_v3.py", "main_v3b.py", "main_v3c.py"]
             if os.path.exists(os.path.join(ROOT, f))]

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

WORKERS = 4


def sample():
    p = {}
    for k, (lo, hi) in SPACE.items():
        if k == "overshoot":
            p[k] = random.randint(int(lo), int(hi))
        else:
            p[k] = round(random.uniform(lo, hi), 3)
    return p


def neighbor(params):
    p = dict(params)
    k = random.choice(list(SPACE.keys()))
    lo, hi = SPACE[k]
    if k == "overshoot":
        p[k] = max(int(lo), min(int(hi), p[k] + random.choice([-1, 1])))
    else:
        span = (hi - lo) * 0.15
        p[k] = round(min(hi, max(lo, p[k] + random.uniform(-span, span))), 3)
    return p


def one_game(cand, opp, seed, order):
    try:
        from kaggle_environments import make
        with contextlib.redirect_stderr(io.StringIO()):
            env = make("orbit_wars",
                       configuration={"seed": seed, "episodeSteps": 220},
                       debug=False)
            if order == 0:
                env.run([cand, opp])
                r = env.steps[-1]
                me, op = r[0]["reward"], r[1]["reward"]
            else:
                env.run([opp, cand])
                r = env.steps[-1]
                op, me = r[0]["reward"], r[1]["reward"]
        return 1 if (me is not None and op is not None and me > op) else 0
    except Exception:
        return 0


def score_candidate(params, n_seeds):
    cand = os.path.join(ROOT, "_cand_%d.py" % os.getpid())
    try:
        subprocess.run(["python3", MAKER, json.dumps(params), cand],
                       check=True, capture_output=True)
    except Exception:
        return 0.0
    wins = total = 0
    for opp in OPPONENTS:
        for seed in range(n_seeds):
            for order in (0, 1):
                wins += one_game(cand, opp, seed, order)
                total += 1
    try:
        if os.path.exists(cand):
            os.remove(cand)
    except Exception:
        pass
    return wins / total if total else 0.0


def _worker(args):
    params, n_seeds = args
    try:
        return score_candidate(params, n_seeds), params
    except Exception:
        return 0.0, params


def save_best(rate, params):
    try:
        with open(BEST_JSON, "w") as f:
            json.dump({"win_rate": rate, "params": params}, f, indent=2)
        subprocess.run(["python3", MAKER, json.dumps(params), TRAINED],
                       check=True, capture_output=True)
    except Exception:
        pass


def main():
    n_random = int(sys.argv[1]) if len(sys.argv) > 1 else 111
    n_seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    n_refine = int(sys.argv[3]) if len(sys.argv) > 3 else 33

    print("Crash-proof overnight trainer")
    print("  opponents: %s" % ", ".join(os.path.basename(o) for o in OPPONENTS))
    print("  workers: %d   random: %d   refine: %d   seeds: %d" %
          (WORKERS, n_random, n_refine, n_seeds))
    print("  each candidate plays %d games" % (len(OPPONENTS) * n_seeds * 2))
    print("  saves continuously, safe to Ctrl-C anytime\n")

    best = None
    best_rate = -1.0
    done = 0

    if os.path.exists(BEST_JSON):
        try:
            prev = json.load(open(BEST_JSON))
            best = prev.get("params")
            best_rate = float(prev.get("win_rate", -1.0))
            print("  resuming from saved best: %.0f%%\n" % (best_rate * 100))
        except Exception:
            pass

    pool = None
    try:
        pool = mp.Pool(WORKERS, maxtasksperchild=8)
        batch = [(sample(), n_seeds) for _ in range(n_random)]
        for rate, params in pool.imap_unordered(_worker, batch):
            done += 1
            flag = ""
            if rate > best_rate:
                best_rate = rate
                best = params
                save_best(best_rate, best)
                flag = "  <-- new best, saved"
            print("  [random %3d/%3d] win %3.0f%%   best %3.0f%%%s" %
                  (done, n_random, rate * 100, best_rate * 100, flag))
        pool.close()
        pool.join()

        print("\nPhase 1 done. Best %.0f%%. Refining...\n" % (best_rate * 100))

        pool = mp.Pool(WORKERS, maxtasksperchild=8)
        refine_batch = [(neighbor(best), n_seeds) for _ in range(n_refine)]
        for rate, params in pool.imap_unordered(_worker, refine_batch):
            flag = ""
            if rate > best_rate:
                best_rate = rate
                best = params
                save_best(best_rate, best)
                flag = "  <-- new best, saved"
            print("  [refine] win %3.0f%%   best %3.0f%%%s" %
                  (rate * 100, best_rate * 100, flag))
        pool.close()
        pool.join()

    except KeyboardInterrupt:
        print("\n\nInterrupted. Best so far is saved.")
        try:
            if pool:
                pool.terminate()
        except Exception:
            pass

    if best is not None:
        save_best(best_rate, best)
        print("\nFINAL best win rate vs field: %.0f%%" % (best_rate * 100))
        print(json.dumps(best, indent=2))
        print("\nWrote main_trained.py")
    else:
        print("\nNo candidate completed.")


if __name__ == "__main__":
    main()
