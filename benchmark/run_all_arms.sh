#!/usr/bin/env bash
# 4 arms x N reps, interleaved per rep (fair cache), medians at the end.
#   baseline | tokopt | farthing | combo(farthing+tokopt)
#
# Toggles the caveman plugin OFF for the whole run (it contaminates every arm) and
# toggles farthing's global hooks ON only for the farthing/combo arms.
# Restores caveman + uninstalls farthing hooks on exit, no matter what.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
PROJECT=${1:-/tmp/express-bench}
REPS=${REPS:-3}
SETTINGS="$HOME/.claude/settings.json"
SCROOGE_REPO=${SCROOGE_REPO:-/Users/dor/Documents/code/NadirCoder}
CSV="$HERE/ab_results.csv"

caveman(){ python3 -c "
import json;p='$SETTINGS';d=json.load(open(p));d['enabledPlugins']['caveman@caveman']=$1;json.dump(d,open(p,'w'),indent=2)"; }
farthing_on(){  (cd "$SCROOGE_REPO" && node packages/cli/src/index.ts init --yes >/dev/null 2>&1) && echo "[driver] farthing hooks ON"; }
farthing_off(){ (cd "$SCROOGE_REPO" && node packages/cli/src/index.ts uninstall --yes >/dev/null 2>&1) && echo "[driver] farthing hooks OFF"; }

cleanup(){ echo "[driver] restoring env…"; farthing_off; caveman True; echo "[driver] caveman restored"; }
trap cleanup EXIT

cp "$SETTINGS" /tmp/settings.allarms.bak && echo "[driver] settings backed up -> /tmp/settings.allarms.bak"
caveman False; echo "[driver] caveman OFF for the run"
rm -f "$CSV"

for rep in $(seq 1 "$REPS"); do
  echo "########## REP $rep / $REPS ##########"
  farthing_off
  for arm in baseline tokopt; do
    echo "----- rep$rep $arm -----"; bash "$HERE/ab_session.sh" "$arm" "$PROJECT"
  done
  farthing_on
  for arm in farthing combo; do
    echo "----- rep$rep $arm -----"; bash "$HERE/ab_session.sh" "$arm" "$PROJECT"
  done
done

echo; echo "===== MEDIANS over $REPS reps ====="
python3 - "$CSV" << 'PY'
import csv,sys,statistics as st
rows=list(csv.DictReader(open(sys.argv[1])))
arms=["baseline","tokopt","farthing","combo"]
# per (arm,rep) session totals, then median across reps
tot={}
for r in rows:
    k=(r["arm"], r["turn"])
for a in arms:
    rs=[x for x in rows if x["arm"]==a]
    if not rs: continue
    # sessions are 6 turns each, in order -> chunk
    costs=[float(x["cost_usd"]) for x in rs]
    cc=[int(x["cache_create"]) for x in rs]
    sess=[sum(costs[i:i+6]) for i in range(0,len(costs),6)]
    sessc=[sum(cc[i:i+6]) for i in range(0,len(cc),6)]
    if not sess: continue
    print(f"{a:<9} sessions={[f'${s:.2f}' for s in sess]}  MEDIAN=${st.median(sess):.3f}  cache_create_med={st.median(sessc):,.0f}")
base=[x for x in rows if x["arm"]=="baseline"]
if base:
    bc=[float(x["cost_usd"]) for x in base]; bsess=[sum(bc[i:i+6]) for i in range(0,len(bc),6)]
    bm=st.median(bsess)
    print(f"\nvs baseline (median):")
    for a in arms:
        rs=[x for x in rows if x["arm"]==a]
        if not rs: continue
        c=[float(x["cost_usd"]) for x in rs]; s=[sum(c[i:i+6]) for i in range(0,len(c),6)]
        m=st.median(s)
        print(f"  {a:<9} ${m:.3f}  ({(m-bm)/bm*100:+.1f}%)")
PY
