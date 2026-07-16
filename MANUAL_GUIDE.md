# Manual A/B: real Claude Code session, WITH vs WITHOUT headroom

Run a real interactive `claude` session yourself, type the same prompts twice
(once plain, once through headroom), and read the true token/cost. No scripts.

---

## 0. Prereqs (once)

```bash
# headroom
python3 -m venv ~/.hrvenv && source ~/.hrvenv/bin/activate
pip install "headroom-ai[proxy]"

# a throwaway copy of a real project (so edits don't touch your original)
git clone --depth 1 https://github.com/expressjs/express.git /tmp/proj-base
```

You need **3 terminal tabs**: **A** = the claude session, **B** = the headroom
proxy, **C** = tracking commands.

---

## 1. Start the headroom proxy — Terminal B

```bash
source ~/.hrvenv/bin/activate
headroom proxy --port 8787 --mode token
```
Leave it running. `--mode token` = its compressing default (the mode that actually
tries to save). Keep this tab open.

---

## 2. RUN 1 — BASELINE (no headroom) — Terminal A

```bash
rm -rf /tmp/run-base && cp -R /tmp/proj-base /tmp/run-base
cd /tmp/run-base
claude --dangerously-skip-permissions
```
(`--dangerously-skip-permissions` so edits/commands don't stop to ask — it's a
throwaway copy.)

Now **type these 6 prompts one at a time** — wait for each to finish before the next:

```
1. Read the main source files and summarize the architecture: the key modules and how they connect.
2. Find the largest source file in the repo and read it IN FULL, then explain what it does in detail.
3. Identify one likely bug or fragile edge case. Explain it precisely with file:line.
4. Fix that bug now — make the actual edits.
5. Add one small self-contained feature that fits this codebase and implement it end to end.
6. Review the changes you made and suggest 3 concrete improvements.
```

Then, **still in the session**, read the running cost:
```
/cost
```
Write down the **Total cost** and **Total duration**. Then exit:
```
/exit
```

---

## 3. RUN 2 — HEADROOM — Terminal A

Same thing, but launch claude pointed at the proxy:

```bash
rm -rf /tmp/run-hr && cp -R /tmp/proj-base /tmp/run-hr
cd /tmp/run-hr
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude --dangerously-skip-permissions
```
The **only** difference is `ANTHROPIC_BASE_URL=http://127.0.0.1:8787` — that routes
the whole session through headroom.

Type the **same 6 prompts**, then:
```
/cost
/exit
```
Write down the Total cost again.

---

## 4. Where to see the tracking

### a) In-session (quickest) — the `/cost` command
Type `/cost` any time inside claude. It shows the **session's total cost, tokens,
and duration** live. This is your headline number for each run.

### b) headroom's own claim — Terminal C
While/after the headroom run:
```bash
curl -s localhost:8787/stats | python3 -m json.tool | grep -A6 '"compression"'
curl -s localhost:8787/stats | python3 -c "import sys,json;d=json.load(sys.stdin)['summary'];print('headroom says saved:',d['cost']['savings_pct'],'% | compressed',d['compression']['requests_compressed'],'reqs, avg',d['compression']['avg_compression_pct'],'%')"
```
This is what headroom *reports*. Compare it to the real `/cost`. **They will differ.**

### c) Ground truth — the transcript (Terminal C)
Every session is logged with exact per-message usage. Point at **that run's** project
folder (not all of `~/.claude/projects` — you may have thousands of sessions):
```bash
# pass the run dir you used: /tmp/run-base  or  /tmp/run-hr
RUN=/tmp/run-base
DIR=~/.claude/projects/$(cd "$RUN" && pwd -P | sed 's#/#-#g')   # resolves macOS /tmp -> /private/tmp
J=$(ls -t "$DIR"/*.jsonl | head -1); echo "$J"

# sum every token lane + Opus-priced cost
node -e '
const fs=require("fs"),L=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(Boolean);
let i=0,cc=0,cr=0,o=0;
for(const l of L){try{const u=JSON.parse(l).message?.usage;if(u){i+=u.input_tokens||0;cc+=u.cache_creation_input_tokens||0;cr+=u.cache_read_input_tokens||0;o+=u.output_tokens||0;}}catch(e){}}
const P={i:15,cc:18.75,cr:1.5,o:75};
console.log("input        ",i.toLocaleString());
console.log("cache_create ",cc.toLocaleString(),"  <-- watch this");
console.log("cache_read   ",cr.toLocaleString());
console.log("output       ",o.toLocaleString());
console.log("COST (Opus) $"+((i*P.i+cc*P.cc+cr*P.cr+o*P.o)/1e6).toFixed(4));
' "$J"
```
Do this **right after each run** (baseline, then headroom) and save both outputs.

---

## 5. Compare

| metric | baseline | headroom | who wins |
|--------|---------:|---------:|:--------:|
| `/cost` total $ | … | … | lower |
| transcript `cache_create` | … | … | lower |
| headroom `/stats` "saved %" | — | … | (its claim) |

**Read it like this:**
- If **headroom `/cost` < baseline `/cost`** → it genuinely helps your workflow. Real.
- If **headroom `/cost` > baseline** while its `/stats` says "saved" → the cache-bust is
  real; watch `cache_create` balloon in the transcript. That's the whole finding.

**Do it 2–3×** per arm (cache TTL is 5 min, agents vary) — compare medians, not one run.

---

## Notes

- **Subscription vs API:** `/cost` shows dollars at API-equivalent price. On a Max/Pro
  plan you don't pay that — what matters is **total tokens** (sum input+cache+output
  from the transcript): fewer = more runway before your weekly cap.
- **Same prompts, same project state** each run — that's why we `rm -rf && cp -R` a
  fresh copy before each. Don't reuse a dirty dir.
- **Turn 2** (read the biggest file in full) is deliberate — it's the fat-payload
  case headroom is actually good at. If headroom ever wins, it wins there.
