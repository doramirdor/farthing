#!/usr/bin/env bash
# Full matrix driver: 4 arms x 8 tasks x N reps.
# Order: task-outer, arm-inner -> the 4 arms of a task run back-to-back (fair
# cache state). Restores the caveman plugin at the end no matter what.
set -uo pipefail
cd "$(dirname "$0")/.."
N=${N:-3}
SETTINGS=/Users/dor/.claude/settings.json

restore_caveman() {
  python3 -c "import json;p='$SETTINGS';d=json.load(open(p));d['enabledPlugins']['caveman@caveman']=True;json.dump(d,open(p,'w'),indent=2)" \
    && echo '[matrix] caveman plugin restored'
}
trap restore_caveman EXIT

# fresh headroom proxy
source /private/tmp/claude-501/hrvenv/bin/activate
pkill -f 'headroom proxy' 2>/dev/null; sleep 1
nohup headroom proxy --port 8787 > /private/tmp/claude-501/proxy2.log 2>&1 &
sleep 8
curl -s http://127.0.0.1:8787/health -m 4 >/dev/null && echo '[matrix] proxy UP' || echo '[matrix] proxy DOWN — headroom arm will error'

rm -f benchmark/results.csv
for t in T1 T2 T3 T4 T5 T6 T7 T8; do
  for arm in baseline headroom scrooge caveman; do
    echo "===== $t / $arm ====="
    bash benchmark/run_bench.sh "$arm" "$t" "$N"
  done
done
echo ALL_DONE
