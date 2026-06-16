#!/bin/zsh
cd "$(dirname "$0")"
echo "Pulling fresh Orbit Wars data..."
python3 tools/refresh.py --team theburroship
git add netlify/data.json
git commit -m "data refresh $(date '+%Y-%m-%d %H:%M')" && git push
echo "Done. Netlify will redeploy in about a minute."
