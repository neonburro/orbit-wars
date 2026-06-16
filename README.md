# Orbit Wars Agent

Kaggle competition: https://www.kaggle.com/competitions/orbit-wars

This is a Kaggle bot competition. There is no web app, server, or deploy step.
You write main.py, the kaggle CLI uploads it, and Kaggle runs it on their
servers against other submitted bots. No Netlify, no hosting, nothing like that.
This GitHub repo is version control only.

## Current submission: v2 (main.py)

A coordinated ROI bot:

- Coordinated multi-planet captures. One strong target can be taken by combining ships from several planets in the same turn, gathering from the closest first.
- Defense. Detects enemy fleets aimed at our planets and reserves enough ships to survive the hit.
- Anti-leader targeting (4p). Tallies every player's strength and prioritizes attacking whoever is winning.
- Comet hunting. Captures comets for free production, holds them with a minimal garrison.
- Target leading and sun avoidance. Fleets aim where orbiting planets will be, and any launch crossing the sun is discarded.

Verified: beats the v1 sniper-style bot 9-3 from both seats, 12-0 vs random, ~1.1 ms per turn vs a 1000 ms timeout.

## The arena

arena.py benchmarks any two bots head to head across many seeds from BOTH seat
positions, so first-move advantage cancels out. This is how you tell whether a
change is actually better instead of guessing.

    python3 arena.py main.py v2.py 15

It reports a win record and flags any games where a bot errored.

## v3 experiments (not submitted)

v3 added: crediting our own inbound fleets to avoid over-sending, game-phase
awareness (expand early, consolidate late), and active defensive reserves.
Across repeated arena runs v3 and its variants (v3b lower reserves, v3c looser
inbound crediting) all landed at 43 to 50 percent against v2. None beat it
cleanly, so v2 stays the submission. The arena caught this before submitting.

The variant files are kept for further iteration:
main_v3.py, main_v3b.py, main_v3c.py, v2.py (the current main.py).

## Install on macOS

System python3 is too old. Use Homebrew Python, and pygame needs SDL headers:

    brew install python
    brew install sdl2 sdl2_image sdl2_mixer sdl2_ttf
    python3 -m pip install --break-system-packages "kaggle-environments>=1.28.0" kaggle kagglehub

## Local test

    python3 -c "from kaggle_environments import make; env=make('orbit_wars', configuration={'seed':42}, debug=True); env.run(['main.py','random']); print([(i,s['reward']) for i,s in enumerate(env.steps[-1])])"

## Auth and submit

    kaggle auth login
    kaggle competitions submit orbit-wars -f main.py -m "coordinated ROI bot v2"
    kaggle competitions submissions orbit-wars

Up to 5 submissions per day. Only the latest 2 count for final scoring.

## Next ideas to try in the arena

- Predict full combat resolution a few turns ahead, not just garrison plus production.
- Snipe enemy fleets by timing a capture of their destination planet.
- Tune reserve ratios and the leader bonus with a parameter sweep through arena.py.