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
COUNCIL = os.path.join(ROOT, "council")
OPPONENTS = [os.path.join(ROOT, f) for f in
             ["v2.py", "main_v3.py", "main_v3b.py", "main_v3c.py"]
             if os.path.exists(os.path.join(ROOT, f))]

WORKERS = 4

# Each burro biases the search toward its personality.
# Ranges are tighter than the full space, pushing the trainer to explore
# that burro's identity instead of wandering everywhere.
BURROS = {
    "warbleur": {  # the aggressor: low reserve, hunts enemies, denies
        "reserve_ratio": (0.05, 0.15),
        "reserve_ratio_late": (0.15, 0.28),
        "leader_bonus": (1.2, 2.0),
        "enemy_bonus": (0.6, 1.2),
        "comet_bonus": (0.0, 0.6),
        "prod_weight": (0.5, 1.2),
        "inbound_thresh": (0.6, 0.85),
        "overshoot": (2, 4),
    },
    "volt": {  # the reactor: economy snowball, high production focus
        "reserve_ratio": (0.12, 0.25),
        "reserve_ratio_late": (0.25, 0.40),
        "leader_bonus": (0.8, 1.6),
        "enemy_bonus": (0.0, 0.4),
        "comet_bonus": (0.3, 0.9),
        "prod_weight": (1.8, 2.5),
        "inbound_thresh": (0.55, 0.8),
        "overshoot": (1, 3),
    },
    "cypher": {  # the builder: balanced, clean expansion, solid defense
        "reserve_ratio": (0.10, 0.22),
        "reserve_ratio_late": (0.25, 0.40),
        "leader_bonus": (0.8, 1.5),
        "enemy_bonus": (0.2, 0.6),
        "comet_bonus": (0.2, 0.7),
        "prod_weight": (1.0, 1.8),
        "inbound_thresh": (0.6, 0.85),
        "overshoot": (2, 3),
    },
    "aster": {  # the wildcard: comet edges, high variance
        "reserve_ratio": (0.05, 0.20),
        "reserve_ratio_late": (0.15, 0.35),
        "leader_bonus": (1.0, 2.0),
        "enemy_bonus": (0.2, 0.8),
        "comet_bonus": (0.9, 1.5),
        "prod_weight": (0.8, 1.8),
        "inbound_thresh": (0.55, 0.9),
        "overshoot": (2, 4),
    },
}


def sample(space):
    p = {}
    for k, (lo, hi) in space.items():
        if k == "overshoot":
            p[k] = random.randint(int(lo), int(hi))
        else:
            p[k] = round(random.uniform(lo, hi), 3)
    return p


def neighbor(params, space):
    p = dict(params)
    k = random.choice(list(space.keys()))
    lo, hi = space[k]
    if k == "overshoot":
        p[k] = max(int(lo), min(int(hi), p[k] + random.choice([-1, 1])))
    else:
        span = (hi - lo) * 0.2
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


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in BURROS:
        print("usage: python3 tools/train_burro.py <warbleur|volt|cypher|aster> [random] [seeds] [refine]")
        return
    name = sys.argv[1]
    space = BURROS[name]
    n_random = int(sys.argv[2]) if len(sys.argv) > 2 else 80
    n_seeds = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    n_refine = int(sys.argv[4]) if len(sys.argv) > 4 else 25

    os.makedirs(COUNCIL, exist_ok=True)
    best_json = os.path.join(COUNCIL, "%s_best.json" % name)
    trained = os.path.join(ROOT, "main_%s.py" % name)

    def save_best(rate, params):
        try:
            with open(best_json, "w") as f:
                json.dump({"burro": name, "win_rate": rate, "params": params}, f, indent=2)
            subprocess.run(["python3", MAKER, json.dumps(params), trained],
                           check=True, capture_output=True)
        except Exception:
            pass

    print("Training burro: %s" % name.upper())
    print("  opponents: %s" % ", ".join(os.path.basename(o) for o in OPPONENTS))
    print("  workers: %d   random: %d   refine: %d   seeds: %d" %
          (WORKERS, n_random, n_refine, n_seeds))
    print("  saves to council/%s_best.json + main_%s.py, safe to Ctrl-C\n" % (name, name))

    best = None
    best_rate = -1.0
    if os.path.exists(best_json):
        try:
            prev = json.load(open(best_json))
            best = prev.get("params")
            best_rate = float(prev.get("win_rate", -1.0))
            print("  resuming %s from %.0f%%\n" % (name, best_rate * 100))
        except Exception:
            pass

    pool = None
    done = 0
    try:
        pool = mp.Pool(WORKERS, maxtasksperchild=8)
        batch = [(sample(space), n_seeds) for _ in range(n_random)]
        for rate, params in pool.imap_unordered(_worker, batch):
            done += 1
            flag = ""
            if rate > best_rate:
                best_rate = rate
                best = params
                save_best(best_rate, best)
                flag = "  <-- new best, saved"
            print("  [%s %3d/%3d] win %3.0f%%   best %3.0f%%%s" %
                  (name, done, n_random, rate * 100, best_rate * 100, flag))
        pool.close()
        pool.join()

        print("\n%s phase 1 done. Best %.0f%%. Refining...\n" % (name.upper(), best_rate * 100))
        pool = mp.Pool(WORKERS, maxtasksperchild=8)
        refine = [(neighbor(best, space), n_seeds) for _ in range(n_refine)]
        for rate, params in pool.imap_unordered(_worker, refine):
            flag = ""
            if rate > best_rate:
                best_rate = rate
                best = params
                save_best(best_rate, best)
                flag = "  <-- new best, saved"
            print("  [%s refine] win %3.0f%%   best %3.0f%%%s" %
                  (name, rate * 100, best_rate * 100, flag))
        pool.close()
        pool.join()
    except KeyboardInterrupt:
        print("\n\n%s interrupted. Best saved." % name.upper())
        try:
            if pool:
                pool.terminate()
        except Exception:
            pass

    if best is not None:
        save_best(best_rate, best)
        print("\n%s FINAL: %.0f%% vs field" % (name.upper(), best_rate * 100))
        print(json.dumps(best, indent=2))
        print("\nWrote main_%s.py" % name)
    else:
        print("\n%s: no candidate completed." % name.upper())


if __name__ == "__main__":
    main()