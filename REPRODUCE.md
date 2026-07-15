# Reproduce it yourself

## Prereqs

- **Claude Code CLI** logged in (`claude` on PATH, subscription or API key). Check: `claude --version`.
- **Node ≥ 22**, **python3**, **git**, `uuidgen` (macOS/Linux have it).
- **headroom** in a venv:
  ```bash
  python3 -m venv ~/.hrvenv && source ~/.hrvenv/bin/activate
  pip install "headroom-ai[proxy]"
  headroom --version
  ```

```bash
git clone https://github.com/doramirdor/nadir-bench.git
cd nadir-bench
```

> Every run below costs real Opus tokens on your account and edits only throwaway
> copies under `/tmp`. Each `claude` call uses `--allowedTools` so it can read/edit.

---

## A. Real-project sessions on express (the headline test)

```bash
# 1. clone the target + install its deps (once)
git clone --depth 1 https://github.com/expressjs/express.git /tmp/express-bench
( cd /tmp/express-bench && npm install )

# 2. start headroom proxy in TOKEN mode (its compressing default)
source ~/.hrvenv/bin/activate
headroom proxy --port 8787 --mode token &

# 3. run a monitored session: <baseline|headroom> <trace|feature|bugfix>
bash benchmark/express_session.sh baseline trace
bash benchmark/express_session.sh headroom trace     # prints /stats after
```

Each turn prints `cost / input / cache_create / cache_read / output`. Rows also land
in `benchmark/results_express.csv`. Compare the `baseline` vs `headroom` session
totals — and compare headroom's `/stats` "saved" line to the *actual* total.

Full 6-session sweep:
```bash
for task in trace feature bugfix; do
  for arm in baseline headroom; do bash benchmark/express_session.sh $arm $task; done
done
```

---

## B. Agentic matrix on the calculator (4 arms × 8 tasks)

```bash
( cd bench-calculator && npm test )          # confirm the fixture is green first
bash benchmark/run_matrix.sh                  # 4 arms × 8 tasks × N=3 = 96 runs
column -s, -t benchmark/results.csv | less    # per-run rows
```

`run_matrix.sh` toggles the caveman plugin off during the run and **restores it via
a trap on exit** (it edits `~/.claude/settings.json` `enabledPlugins` — backup first
if you're cautious: `cp ~/.claude/settings.json ~/settings.bak`).

Single cell only:
```bash
bash benchmark/run_bench.sh baseline T3 3      # arm, task, N reps -> median of PASS
```

---

## C. headroom multi-turn (cache vs token mode)

```bash
headroom proxy --port 8787 --mode token &      # or --mode cache
bash benchmark/run_headroom_multiturn.sh baseline
bash benchmark/run_headroom_multiturn.sh headroom
```

---

## D. scrooge audit on YOUR real bill (no network, no spend)

In the scrooge repo (not this one):
```bash
node packages/cli/src/index.ts audit           # decompose your ~/.claude bill
node packages/cli/src/index.ts audit --json     # machine-readable
```

---

## Reading results honestly

- Compare the **session total** (sum of per-turn `total_cost_usd`), not any tool's
  own dashboard. The express test exists because those diverge — headroom's `/stats`
  reported a *saving* while the real bill rose 45–99%.
- Watch **`cache_create`**: prefix-rewriting tools inflate it, and that cost shows up
  in the bill but not in their ledger.
- Cost is noisy (cache TTL 5 min, agent nondeterminism). Repeat N≥3, take the median,
  interleave arms — don't batch all baselines then all headroom.
- Only compare cost among runs that **passed** the accuracy check.
