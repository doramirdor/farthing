#!/usr/bin/env bash
# FAITHFUL headroom test: a real multi-turn session (chained --resume) so context
# accumulates in the uncached "live zone" that headroom actually compresses.
# Runs the same 6-turn task as baseline (direct) and headroom (via proxy), sums
# cost across turns, and reads headroom's own /stats after.
#   ./run_headroom_multiturn.sh <baseline|headroom>
set -uo pipefail
ARM=${1:?arm: baseline|headroom}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../bench-calculator" && pwd)
WORK=${WORK:-/tmp/bench-mt}
PROXY=http://127.0.0.1:8787
TOOLS="Read,Edit,Bash"
CSV="$HERE/results_multiturn.csv"

# 6 turns that build a large live zone (reads pile up), then edit + verify.
TURNS=(
"Read src/operations.js, src/parser.js and src/evaluator.js. Summarize how a function call like abs(x) flows through tokenize -> parse -> eval."
"Also read src/tokenizer.js and test/calculator.test.js and test/operations.test.js. List every place that assumes functions take exactly one argument."
"Add a two-argument max(a, b) function to the registry in operations.js so max(3,7) is 7. Do not wire the parser yet."
"Now update the parser/evaluator so two-argument function calls with a comma work end to end."
"Add a test asserting calculate('max(3, 7)') === 7 to the test suite."
"Run npm test. If anything fails, read the failure and fix it until green."
)

setup() { rm -rf "$WORK"; cp -R "$SRC" "$WORK"; cd "$WORK"; git init -q; git -c user.email=b@b -c user.name=b add -A; git -c user.email=b@b -c user.name=b commit -qm base; }
call() { # $1=prompt $2=resume-sid-or-empty
  # turn 1: set --session-id. turns 2+: --resume only (never both — they conflict).
  local idflag
  if [ -n "$2" ]; then idflag="--resume $SID"; else idflag="--session-id $SID"; fi
  if [ "$ARM" = headroom ]; then
    ANTHROPIC_BASE_URL="$PROXY" claude -p "$1" $idflag --allowedTools "$TOOLS" --output-format json 2>/dev/null
  else
    claude -p "$1" $idflag --allowedTools "$TOOLS" --output-format json 2>/dev/null
  fi
}
cost_of() { echo "$1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const d=JSON.parse(s);const u=d.usage||{};console.log([d.total_cost_usd||0,u.input_tokens||0,u.cache_read_input_tokens||0,u.output_tokens||0].join(" "))}catch(e){console.log("0 0 0 0")}})'; }

setup
SID=$(uuidgen)
[ -f "$CSV" ] || echo "arm,turn,cost_usd,input,cache_read,output" > "$CSV"
total=0; resume=""
for i in "${!TURNS[@]}"; do
  OUT=$(call "${TURNS[$i]}" "$resume")
  read -r C IN CR O < <(cost_of "$OUT")
  echo "$ARM,$((i+1)),$C,$IN,$CR,$O" >> "$CSV"
  echo "[$ARM turn$((i+1))] \$$C in=$IN cr=$CR out=$O"
  total=$(node -e "console.log($total + ${C:-0})")
  resume="$SID"
done
echo "== $ARM total session cost: \$$total =="
if [ "$ARM" = headroom ]; then
  echo "== headroom /stats =="; curl -s "$PROXY/stats" -m 5
fi
