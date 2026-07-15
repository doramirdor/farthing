#!/usr/bin/env bash
# Monitored, multi-turn Claude Code session on a REAL project (express).
# Runs one of 3 realistic tasks (trace / feature / bugfix) as a chained
# --resume session, per-arm, and MONITORS each turn: cost, input, cache_read,
# output. Reads headroom /stats after a headroom session.
#   ./express_session.sh <baseline|headroom> <trace|feature|bugfix>
set -uo pipefail
ARM=${1:?arm: baseline|headroom}
TASK=${2:?task: trace|feature|bugfix}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=/tmp/express-bench
WORK=/tmp/express-work
PROXY=http://127.0.0.1:8787
TOOLS="Read,Edit,Bash,Grep,Glob"
CSV="$HERE/results_express.csv"

case "$TASK" in
  trace) TURNS=(
"Read lib/express.js and lib/application.js. Explain how an express() app is created and how app.listen / app.handle wire up. Cite exact functions and files."
"Now read lib/request.js and lib/response.js. Trace how res.json(obj) works end to end: which prototype it is defined on, how it sets Content-Type, and how the body is serialized and sent."
"Read lib/utils.js and lib/view.js. Explain how res.render(view) resolves a template through the View abstraction and the app's view cache."
"Summarize the full request lifecycle from an incoming HTTP request to a JSON response, naming every lib/*.js file it passes through and the key function in each."
) ;;
  feature) TURNS=(
"Read lib/response.js and note the style of res.json and res.send (how they set headers and end the response)."
"Add a res.sendError(code, message) method to lib/response.js that sets the HTTP status to code and sends a JSON body { error: message, status: code }, matching the surrounding code style."
"Read test/res.json.js (or a similar res.*.js test) to learn the test conventions used here."
"Add a focused test file test/res.sendError.js covering res.sendError(404, 'nope'): assert status 404 and the JSON body. Wire nothing else."
"Run: npx mocha --reporter spec test/res.sendError.js . If it fails, read the failure and fix until green."
) ;;
  bugfix) TURNS=(
"Read lib/response.js and focus on res.location() and res.redirect(). Explain how the 'back' magic value and the Referrer/Location header are handled."
"Read lib/request.js and lib/utils.js for anything res.location/redirect depends on (e.g. encodeUrl, host resolution)."
"Identify one concrete edge case in res.location()/res.redirect() URL handling that could misbehave (e.g. missing referrer, protocol-relative or malformed URL). State it precisely."
"Harden res.location() for that edge case in lib/response.js, preserving current behavior for normal inputs."
"Add a test test/res.location.edge.js for the edge case and run: npx mocha --reporter spec test/res.location.edge.js . Fix until green."
) ;;
  *) echo "bad task $TASK"; exit 2 ;;
esac

setup() { rm -rf "$WORK"; cp -R "$SRC" "$WORK"; cd "$WORK"; git init -q >/dev/null 2>&1; git -c user.email=b@b -c user.name=b add -A >/dev/null 2>&1; git -c user.email=b@b -c user.name=b commit -qm base >/dev/null 2>&1; }
call() {
  local idflag; if [ -n "$2" ]; then idflag="--resume $SID"; else idflag="--session-id $SID"; fi
  if [ "$ARM" = headroom ]; then
    ANTHROPIC_BASE_URL="$PROXY" claude -p "$1" $idflag --allowedTools "$TOOLS" --output-format json 2>/dev/null
  else
    # baseline AND scrooge both run plain claude; scrooge differs by having its
    # hooks enabled globally (scrooge init) — no proxy, no prefix rewrite.
    claude -p "$1" $idflag --allowedTools "$TOOLS" --output-format json 2>/dev/null
  fi
}
row() { echo "$1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const d=JSON.parse(s);const u=d.usage||{};console.log([d.total_cost_usd||0,u.input_tokens||0,u.cache_creation_input_tokens||0,u.cache_read_input_tokens||0,u.output_tokens||0].join(" "))}catch(e){console.log("0 0 0 0 0")}})'; }

setup
SID=$(uuidgen)
[ -f "$CSV" ] || echo "arm,task,turn,cost_usd,input,cache_create,cache_read,output,sec" > "$CSV"
echo "===== MONITOR: $ARM / $TASK  (session $SID) ====="
printf "%-6s %-7s %-9s %8s %8s %10s %8s %5s\n" turn "" cost in cache_cr cache_rd out sec
total=0; resume=""
for i in "${!TURNS[@]}"; do
  t0=$(date +%s); OUT=$(call "${TURNS[$i]}" "$resume"); t1=$(date +%s)
  read -r C IN CC CR O < <(row "$OUT"); SEC=$((t1-t0))
  echo "$ARM,$TASK,$((i+1)),$C,$IN,$CC,$CR,$O,$SEC" >> "$CSV"
  printf "turn%-2s        \$%-8s %8s %8s %10s %8s %4ss\n" "$((i+1))" "$C" "$IN" "$CC" "$CR" "$O" "$SEC"
  total=$(node -e "console.log(($total)+(${C:-0}))")
  resume="$SID"
done
echo "== $ARM/$TASK session total: \$$total =="
[ "$ARM" = headroom ] && { echo "-- headroom /stats --"; curl -s "$PROXY/stats" -m 5 | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const x=JSON.parse(s).summary;console.log("compressed:",x.compression.requests_compressed,"avg%:",x.compression.avg_compression_pct,"removed:",x.compression.total_tokens_removed,"frozen:",JSON.stringify(x.uncompressed_requests),"cost w/o:",x.cost.without_headroom_usd,"with:",x.cost.with_headroom_usd)}) '; }
