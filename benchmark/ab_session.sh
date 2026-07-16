#!/usr/bin/env bash
# A/B a real Claude Code coding session WITH vs WITHOUT headroom, same prompts.
# Covers the full mix: read/analyze, fat-file read (headroom's best case),
# find bug, fix bug, add feature, suggest improvements. Meters every turn.
#
#   ./ab_session.sh <baseline|headroom> /path/to/your/project
#
# Run it TWICE (baseline, then headroom), compare the session totals.
set -uo pipefail
ARM=${1:?arm: baseline | headroom}
PROJECT=${2:?path to a real git project to run against}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-/tmp/ab-work}
PROXY=http://127.0.0.1:8787
TOOLS="Read,Edit,Bash,Grep,Glob"
CSV="$HERE/ab_results.csv"

# The identical prompt sequence for BOTH arms. Generic — works on any codebase.
TURNS=(
"Read the main source files in this project and summarize the architecture: the key modules and how they connect. Use Read/Grep/Glob."
"Find the largest source file in the repo and read it IN FULL. Explain what it does in detail. (This is the big-payload turn.)"
"Identify one likely bug or fragile edge case in the code. Explain it precisely with file:line and why it is wrong."
"Fix that bug now. Make the actual edit(s)."
"Add one small, self-contained feature that fits this codebase, and implement it end to end."
"Review the changes you made this session and suggest 3 concrete, specific improvements."
)

setup(){ rm -rf "$WORK"; cp -R "$PROJECT" "$WORK"; cd "$WORK";
  git init -q >/dev/null 2>&1; git -c user.email=b@b -c user.name=b add -A >/dev/null 2>&1;
  git -c user.email=b@b -c user.name=b commit -qm base >/dev/null 2>&1 || true; }
call(){ local idflag; if [ -n "$2" ]; then idflag="--resume $SID"; else idflag="--session-id $SID"; fi
  if [ "$ARM" = headroom ]; then ANTHROPIC_BASE_URL="$PROXY" claude -p "$1" $idflag --allowedTools "$TOOLS" --output-format json 2>/dev/null
  else claude -p "$1" $idflag --allowedTools "$TOOLS" --output-format json 2>/dev/null; fi; }
row(){ echo "$1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const d=JSON.parse(s),u=d.usage||{};console.log([d.total_cost_usd||0,u.input_tokens||0,u.cache_creation_input_tokens||0,u.cache_read_input_tokens||0,u.output_tokens||0].join(" "))}catch(e){console.log("0 0 0 0 0")}})'; }

setup; SID=$(uuidgen)
[ -f "$CSV" ] || echo "arm,turn,cost_usd,input,cache_create,cache_read,output,sec" > "$CSV"
echo "===== $ARM  ·  $(basename "$PROJECT")  ·  session $SID ====="
printf "%-7s %10s %8s %10s %10s %8s %5s\n" turn cost input cache_cr cache_rd output sec
tot=0 ci=0 cc=0 cr=0 co=0; resume=""
for i in "${!TURNS[@]}"; do
  t0=$(date +%s); OUT=$(call "${TURNS[$i]}" "$resume"); t1=$(date +%s)
  read -r C IN CCR CRD O < <(row "$OUT"); S=$((t1-t0))
  echo "$ARM,$((i+1)),$C,$IN,$CCR,$CRD,$O,$S" >> "$CSV"
  printf "turn%-3s \$%-9s %8s %10s %10s %8s %4ss\n" "$((i+1))" "$C" "$IN" "$CCR" "$CRD" "$O" "$S"
  tot=$(node -e "console.log($tot+${C:-0})"); ci=$((ci+IN)); cc=$((cc+CCR)); cr=$((cr+CRD)); co=$((co+O))
  resume="$SID"
done
echo "-------------------------------------------------------------"
printf "TOTAL  \$%-9s  input=%s  cache_create=%s  cache_read=%s  output=%s\n" "$tot" "$ci" "$cc" "$cr" "$co"
[ "$ARM" = headroom ] && { echo "-- headroom /stats (its own claim) --"; curl -s "$PROXY/stats" -m5 | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const x=JSON.parse(s).summary;console.log("compressed:",x.compression.requests_compressed,"avg%:",x.compression.avg_compression_pct,"removed:",x.compression.total_tokens_removed,"| headroom says saved:",x.cost.savings_pct+"%")})'; }
