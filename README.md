# Orbit Wars Agent

Kaggle competition: https://www.kaggle.com/competitions/orbit-wars

## Strategy (v2)

`main.py` is a coordinated ROI bot. Over v1 it adds:

- Coordinated multi-planet captures. A single strong target can be taken by combining ships from several of our planets in the same turn, gathering from the closest planets first.
- Defense. Detects enemy fleets whose heading aligns with one of our planets and reserves enough ships there to survive the hit, instead of emptying a planet about to be attacked.
- Anti-leader targeting (4p). Computes every player's total strength and adds a scoring bonus for attacking the current leader's planets, so in a free-for-all we gang the strongest player rather than feed them.
- Comet hunting. Comets are free production while they last, so capturing them gets a scoring bonus and they are held with a minimal garrison since they expire.
- Target leading and sun avoidance (carried over): fleets aim where orbiting planets will be, and any launch whose path crosses the sun is discarded.

Verified locally: beats v1 9-3 from both seat positions, 12-0 vs random, wins 4-player games clean. About 1.1 ms per turn against a 1000 ms timeout.

## Install on macOS

The system python3 is too old and only sees kaggle-environments up to 1.18. Install a modern Python via Homebrew first:

    brew install python
    python3 -m pip install --user "kaggle-environments>=1.28.0" kaggle kagglehub

## Local testing

    python3 -c "from kaggle_environments import make; env=make('orbit_wars', configuration={'seed':42}, debug=True); env.run(['main.py','random']); print([(i,s['reward']) for i,s in enumerate(env.steps[-1])])"

## Submitting

    mkdir -p ~/.kaggle
    nano ~/.kaggle/access_token
    chmod 600 ~/.kaggle/access_token
    kaggle competitions submit orbit-wars -f main.py -m "coordinated ROI bot v2"

You get up to 5 submissions per day. Only your latest 2 count for final scoring, so iterate freely.

## Ideas for v3

- Account for our own fleets already inbound to a target so we do not over-send.
- Snipe enemy fleets mid-flight by timing a capture of their destination.
- Expansion vs consolidation phase based on turn number and board control.
- Tune the leader bonus and garrison ratios via self-play sweeps.