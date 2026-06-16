"""
Orbit Wars self-play arena.
Usage: python3 tools/arena.py BOT_A BOT_B [N_SEEDS]
Runs BOT_A vs BOT_B across N_SEEDS games from BOTH seats.
"""
import sys, contextlib, io

def run_match(a, b, seed):
    from kaggle_environments import make
    env = make("orbit_wars", configuration={"seed": seed}, debug=False)
    env.run([a, b])
    final = env.steps[-1]
    return final[0]["reward"], final[1]["reward"], [s["status"] for s in final]

def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    bot_a, bot_b = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    a_wins = b_wins = ties = errors = 0
    with contextlib.redirect_stderr(io.StringIO()):
        for seed in range(n):
            r0, r1, st = run_match(bot_a, bot_b, seed)
            if "ERROR" in st: errors += 1
            elif r0 > r1: a_wins += 1
            elif r1 > r0: b_wins += 1
            else: ties += 1
            r0, r1, st = run_match(bot_b, bot_a, seed)
            if "ERROR" in st: errors += 1
            elif r1 > r0: a_wins += 1
            elif r0 > r1: b_wins += 1
            else: ties += 1
    total = a_wins + b_wins + ties
    print(f"{bot_a} vs {bot_b}  ({total} games, both seats)")
    print(f"  {bot_a}: {a_wins}")
    print(f"  {bot_b}: {b_wins}")
    print(f"  ties:   {ties}")
    if errors: print(f"  ERRORS: {errors}")
    if total: print(f"  {bot_a} win rate: {100.0*a_wins/total:.0f}%")

if __name__ == "__main__":
    main()
