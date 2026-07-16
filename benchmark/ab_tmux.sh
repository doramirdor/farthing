#!/usr/bin/env bash
# Drive a REAL interactive Claude Code TUI (not -p) via tmux send-keys, same 6
# prompts, WITH vs WITHOUT headroom. Reads token/cost from the session transcript
# jsonl afterward — the ground truth an interactive session actually produced.
#
#   ./ab_tmux.sh <baseline|headroom> /path/to/project
#
# Requires: tmux, claude, jq (or node). Uses --dangerously-skip-permissions so the
# agent can edit/run without blocking (throwaway /tmp copy only).
set -uo pipefail
ARM=${1:?arm: baseline | headroom}
PROJECT=${2:?path to a project}
WORK=/tmp/abtmux-$ARM
PROXY=http://127.0.0.1:8787
SESS=abtmux_$ARM

TURNS=(
"Read the main source files and summarize the architecture: key modules and how they connect."
"Find the largest source file in the repo and read it IN FULL, then explain what it does in detail."
"Identify one likely bug or fragile edge case. Explain it precisely with file:line."
"Fix that bug now — make the actual edits."
"Add one small self-contained feature that fits this codebase and implement it end to end."
"Review the changes you made and suggest 3 concrete improvements."
)

command -v tmux >/dev/null || { echo "install tmux first: brew install tmux"; exit 1; }
rm -rf "$WORK"; cp -R "$PROJECT" "$WORK"

# env for the arm
ENVPREFIX=""
[ "$ARM" = headroom ] && ENVPREFIX="ANTHROPIC_BASE_URL=$PROXY "

tmux kill-session -t "$SESS" 2>/dev/null || true
tmux new-session -d -s "$SESS" -x 220 -y 50
tmux send-keys -t "$SESS" "cd $WORK && ${ENVPREFIX}claude --dangerously-skip-permissions" Enter
sleep 6   # let the TUI boot

busy(){ tmux capture-pane -p -t "$SESS" | grep -qiE "esc to interrupt|Thinking|Working|Cerebrating|Forging"; }

for i in "${!TURNS[@]}"; do
  echo "[turn $((i+1))] sending…"
  # type the prompt, then Enter
  tmux send-keys -t "$SESS" "${TURNS[$i]}"
  sleep 1
  tmux send-keys -t "$SESS" Enter
  sleep 4
  # wait until idle (no busy marker) for 2 consecutive checks, max ~4 min
  idle=0; waited=0
  while [ $idle -lt 2 ] && [ $waited -lt 240 ]; do
    if busy; then idle=0; else idle=$((idle+1)); fi
    sleep 5; waited=$((waited+5))
  done
  echo "[turn $((i+1))] done (~${waited}s)"
done

# exit the TUI cleanly
tmux send-keys -t "$SESS" "/exit" Enter; sleep 3
tmux kill-session -t "$SESS" 2>/dev/null || true

# find the transcript jsonl for this WORK dir and sum usage
# (resolve real path — macOS /tmp is a symlink to /private/tmp, which claude uses)
HASH=$(cd "$WORK" && pwd -P | sed 's#/#-#g')
DIR="$HOME/.claude/projects/$HASH"
JSONL=$(ls -t "$DIR"/*.jsonl 2>/dev/null | head -1)
echo "===== $ARM (interactive tmux) · transcript: $JSONL ====="
[ -z "$JSONL" ] && { echo "no transcript found under $DIR"; exit 1; }
node -e '
const fs=require("fs"), lines=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(Boolean);
let inp=0,cc=0,cr=0,out=0;
for(const l of lines){ try{const o=JSON.parse(l); const u=o.message&&o.message.usage; if(u){inp+=u.input_tokens||0;cc+=u.cache_creation_input_tokens||0;cr+=u.cache_read_input_tokens||0;out+=u.output_tokens||0;}}catch(e){} }
// Opus list price per 1M
const P={in:15,cc:18.75,cr:1.5,out:75};
const cost=(inp*P.in+cc*P.cc+cr*P.cr+out*P.out)/1e6;
console.log("input       ",inp.toLocaleString());
console.log("cache_create",cc.toLocaleString());
console.log("cache_read  ",cr.toLocaleString());
console.log("output      ",out.toLocaleString());
console.log("COST (Opus) $"+cost.toFixed(4));
' "$JSONL"
[ "$ARM" = headroom ] && { echo "-- headroom /stats --"; curl -s "$PROXY/stats" -m5 | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const x=JSON.parse(s).summary;console.log("compressed:",x.compression.requests_compressed,"avg%:",x.compression.avg_compression_pct,"removed:",x.compression.total_tokens_removed,"| says saved:",x.cost.savings_pct+"%")})'; }
