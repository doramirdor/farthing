#!/usr/bin/env bash
# Agentic coding-cost benchmark runner.
#   ./run_bench.sh <arm> <taskId> [N]
#   arm    : baseline | headroom | scrooge | caveman
#   taskId : T1..T8  (see TASKS.md)
#   N      : repetitions (default 3) — median of PASSING runs is reported
#
# Operates on a throwaway git copy of bench-calculator so the committed repo is
# never dirtied. Records one CSV row per run + prints the median.
set -uo pipefail

ARM=${1:?arm: baseline|headroom|scrooge|caveman}
TASKID=${2:?task id: T1..T8}
N=${3:-3}

HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../bench-calculator" && pwd)
WORK=${WORK:-/tmp/bench-run}
PROXY=${PROXY:-http://127.0.0.1:8787}
CSV="${CSV:-$HERE/results.csv}"
TOOLS="Read,Edit,Bash"

# ---- task table (case-based; portable to bash 3.2 / macOS) ------------------
case "$TASKID" in
  T1) TASK='Add a `sqrt` function to the calculator so `sqrt(9)` returns 3. Add a test.'
      GATE='calculate("sqrt(9)")===3' ;;
  T2) TASK='Add a `tau` constant equal to 2*pi so `calculate("tau")` works. Add a test.'
      GATE='Math.abs(calculate("tau")-2*Math.PI)<1e-9' ;;
  T3) TASK='Add a two-argument `max(a, b)` function, e.g. `max(3, 7)` returns 7. Functions are currently single-arg, so update tokenizer/parser/evaluator as needed.'
      GATE='calculate("max(3, 7)")===7' ;;
  T4) TASK='The tokenizer rejects scientific notation like `1e3`. Add support so `calculate("1e3")` returns 1000.'
      GATE='calculate("1e3")===1000' ;;
  T5) TASK='`calculate("2 ^ -2")` should return 0.25 but currently throws or is wrong. Fix negative exponents.'
      GATE='calculate("2 ^ -2")===0.25' ;;
  T6) TASK='Add integer-division operator `//` (floor division) with the same precedence as `/`, so `7 // 2` is 3.'
      GATE='calculate("7 // 2")===3' ;;
  T7) TASK='Add an `undo()` method to the `Calculator` class that removes the last history entry and returns it.'
      GATE='(()=>{const c=new Calculator();c.eval("1+1");const u=c.undo();return u.result===2&&c.history.length===0;})()' ;;
  T8) TASK='Add a `calculateAll(expressions)` export that takes an array of strings and returns an array of results, skipping (null) any that throw.'
      GATE='JSON.stringify(calculateAll(["2+2","1/0","3*3"]))===JSON.stringify([4,null,9])' ;;
  *)  echo "unknown task $TASKID"; exit 2 ;;
esac

# ---- work copy (git-controlled, reset between runs) -------------------------
setup_work() {
  rm -rf "$WORK"; cp -R "$SRC" "$WORK"; cd "$WORK"
  git init -q
  git -c user.email=b@b.co -c user.name=bench add -A
  git -c user.email=b@b.co -c user.name=bench commit -qm base
  git rev-parse HEAD > /tmp/BENCH_BASE
}
reset_repo() { cd "$WORK"; git reset --hard "$(cat /tmp/BENCH_BASE)" -q; git clean -fdq; }

SCROOGE_LAYER='scrooge terse-output layer. Lead with the answer or code. No preamble, no restating the question. Prefer code blocks and short lists over paragraphs. No wrap-up summary unless asked. Cut hedging and filler. Revert to full prose only for security warnings, irreversible-action confirmations, or ambiguous multi-step plans.'
CAVEMAN_LAYER='Respond terse like smart caveman. Drop articles (a/an/the), filler (just/really/basically), pleasantries, hedging. Fragments OK. Short synonyms. Keep all technical terms, code, API names, CLI commands, and exact error strings verbatim. Code blocks unchanged. No self-reference.'

# NOTE: caveman plugin must be DISABLED globally (enabledPlugins) so it does not
# contaminate baseline/headroom/scrooge. The caveman + scrooge arms re-inject
# their output-style layer here via --append-system-prompt (faithful to the
# output-lane; multi-turn scrooge hooks are out of scope for this harness).
launch() { # $1 = prompt  -> prints claude JSON on stdout
  case "$ARM" in
    baseline) claude -p "$1" --allowedTools "$TOOLS" --output-format json ;;
    headroom) ANTHROPIC_BASE_URL="$PROXY" claude -p "$1" --allowedTools "$TOOLS" --output-format json ;;
    scrooge)  claude -p "$1" --allowedTools "$TOOLS" --append-system-prompt "$SCROOGE_LAYER" --output-format json ;;
    caveman)  claude -p "$1" --allowedTools "$TOOLS" --append-system-prompt "$CAVEMAN_LAYER" --output-format json ;;
    cavemanP) claude -p "$1" --allowedTools "$TOOLS" --output-format json ;;   # FAITHFUL: real caveman plugin must be ENABLED globally
    *) echo "bad arm $ARM" >&2; exit 2 ;;
  esac
}

# accuracy: npm test green (no regression) AND task gate true
accuracy() {
  cd "$WORK"
  npm test >/dev/null 2>&1 || { echo FAIL; return; }
  node -e "import('./src/index.js').then(m=>{const {calculate,Calculator,calculateAll}=m;try{process.exit(($GATE)?0:1)}catch(e){process.exit(1)}})" \
    && echo PASS || echo FAIL
}

# ---- run --------------------------------------------------------------------
setup_work
[ -f "$CSV" ] || echo "ts,arm,task,rep,cost_usd,input,cache_create,cache_read,output,sec,accuracy" > "$CSV"

costs=()
for rep in $(seq 1 "$N"); do
  reset_repo
  t0=$(date +%s)
  OUT=$(launch "$TASK")
  t1=$(date +%s)
  read -r COST IN CC CR OUTT < <(echo "$OUT" | node -e '
    let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const d=JSON.parse(s);const u=d.usage||{};
    console.log([d.total_cost_usd||0,u.input_tokens||0,u.cache_creation_input_tokens||0,u.cache_read_input_tokens||0,u.output_tokens||0].join(" "))}catch(e){console.log("0 0 0 0 0")}})')
  ACC=$(accuracy)
  SEC=$((t1-t0))
  echo "$(date +%FT%T),$ARM,$TASKID,$rep,$COST,$IN,$CC,$CR,$OUTT,$SEC,$ACC" >> "$CSV"
  echo "[$ARM $TASKID rep$rep] \$$COST in=$IN cc=$CC cr=$CR out=$OUTT ${SEC}s $ACC"
  [ "$ACC" = PASS ] && costs+=("$COST")
done

# median cost of passing runs
if [ "${#costs[@]}" -gt 0 ]; then
  MED=$(printf '%s\n' "${costs[@]}" | sort -n | awk '{a[NR]=$1} END{print (NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2}')
  echo "== $ARM $TASKID: median \$$MED over ${#costs[@]}/$N passing runs =="
else
  echo "== $ARM $TASKID: 0/$N passed — no cost median =="
fi
