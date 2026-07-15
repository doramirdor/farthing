# Findings

## ⭐ Headline: the agentic matrix (96 runs, tools ON)

The Q&A findings below were run on a **broken single-shot harness**
(`--allowedTools ""` → no file reads, no cache dynamics). The corrected benchmark
runs real agent loops on `bench-calculator` with Read/Edit/Bash. Result
([`results/matrix.md`](../results/matrix.md), [`results/matrix_raw.csv`](../results/matrix_raw.csv)):

| arm | mean median $/task | vs baseline | accuracy |
|-----|-------------------:|------------:|---------:|
| baseline | $0.311 | — | 23/24 (96%) |
| headroom | $0.581 | **+87%** | 24/24 |
| caveman | $0.360 | **+16%** | 24/24 |
| scrooge terse | $0.296 | **−5%** | 24/24 |

**Where the tokens went** (mean/run): `cache_read` ≈ 190k, `fresh_input` ≈ 6k — a
**30:1** cache-to-fresh ratio even on coding. headroom's proxy pushes fresh_input to
39k (6.3×) by rewriting the cached payload → +87%.

**Conclusions, now on the right workload:**
1. The bill is **cache-dominated**; input/output compressors fight streams that
   barely move it.
2. **headroom actively harms** (+87%) — busting cache costs far more than the input
   tokens it removes.
3. **caveman (output lane) backfires** (+16%) on agentic tasks — fewer output tokens,
   but style noise drives more/longer agent turns.
4. **scrooge terse** is the only saver (−5%), and small — accuracy held at 100%.
5. No single-lane compressor delivers real savings here; the money is in **cache
   dynamics** (Nadir's model-routing axis, or scrooge's multi-turn coordination),
   not token-shaving. This is the whole thesis, now measured on real coding work.

### Isolation method

Caveman is a global plugin (`enabledPlugins`) so it contaminates every nested
`claude -p`. For the matrix it was toggled off (backup + auto-restore via trap),
giving a clean baseline; the caveman/scrooge arms re-inject their **output-style
layer** via `--append-system-prompt`. Faithful to the output lane; scrooge's
multi-turn hook layers (read-ledger, prefix-guard) are out of scope for this harness.

---

## Provenance

| finding | backing |
|---------|---------|
| headroom Q&A A/B (+17%) | **aggregate only** — raw prompts were a private corpus, excluded from this public repo |
| headroom compressed 0 tokens | **raw ledger** — [`data/headroom_proxy_savings_ledger.json`](../data/headroom_proxy_savings_ledger.json) (`tokens_saved: 0`, 223 lifetime requests) |
| scrooge audit ($15,937 bill, 0.3% avoidable) | **raw** — [`data/scrooge_audit_summary.json`](../data/scrooge_audit_summary.json) |
| scrooge terse-output A/B (+0.2% output) | **aggregate only** — private corpus, raw excluded from public repo |
| coding-task N=12 table | **reported** — from live session run; raw per-prompt files not preserved (see caveat) |
| headroom `prefix_frozen` `/stats` | **reported** — from live `headroom /stats` on a 1,200-line file read |
| Nadir −60% / 98% | **vendor** — getnadir.com |

---

## 1. headroom on Q&A: net **+17%** (it made the bill worse)

20 real coding prompts, each run through Opus twice: baseline `claude -p` vs the
same through the headroom proxy. Full table: [`results/headroom_qa_ab.md`](../results/headroom_qa_ab.md).

- **Total**: base $8.50 → headroom $9.95 = **+17.0%**.
- **10 win / 10 lose**, 0 broken outputs (accuracy intact).
- **Cause**: headroom rewrites the payload to shrink input tokens. The rewrite is
  new bytes → **prompt-cache miss** → the model reprocesses formerly-cached context
  at full fresh-input price. On Opus with a big cached prefix, the cache saving it
  destroys > the tokens it removes.
- Worst: prompt #13 $2.16 → $3.90 (+81%); #9 +108%; #5 +53%.
- Wins only where there was little cache to lose (#14 −90%, #4/#8 −65%).

## 2. headroom on coding tasks: **0% — it compressed nothing**

Even on a 1,200-line / ~12k-token single file read, headroom's own `/stats`:

```
compressed: 0    avg_compression: 0%    tokens_removed: 0    saved: $0 (0%)
uncompressed: { prefix_frozen: 3, passthrough: 1 }
```

Confirmed by its lifetime ledger: **223 requests, `tokens_saved: 0`,
`compression_savings_usd: 0.0`** (it only ever rode existing cache: $24.7 cache
savings, which is not compression).

**Why:** headroom is cache-safe *by design*. It **freezes the cached prefix** and
only compresses the uncached "live zone" that accumulates **across turns**. In a
single-shot `claude -p`, the file-read sits in the first/cached turn, so headroom
(correctly) freezes it. **A `claude -p` benchmark structurally cannot exercise
headroom.** Its real opportunity lives in long *multi-turn interactive* sessions
where tool-results pile up — which is also what its own `audit-reads` sizes on the
corpus (8% line-scaffolding + 18.5% stale-reads, of the 68% of traffic that is Reads).

## 2b. scrooge terse-output on the same 20 prompts: **+0.2% output = null**

Ran the identical 20 prompts, baseline vs `claude -p --append-system-prompt
"<scrooge terse-output rules>"`. Full table:
[`results/scrooge_terse_ab.md`](../results/scrooge_terse_ab.md).

- **Output tokens (terse's only lane): 38,549 → 38,622 = +0.2% — a null.** terse did
  not reduce output in single-shot.
- Total-$ delta (+14.8%) is **invalid**: each arm ran separately → different cache
  warmth. The swing is `cache_read` variance, not terse. Proof: #13 $1.46→$3.06
  (+109%, out 16k→24k = cache miss + ramble); #7 +380%, #8 +592% (cache misses);
  the "wins" #5/#11 only won because the model output **0 tokens** (broke).
- **2/20 degenerate** (model answered nothing under terse pressure) — a quality
  regression, exactly what scrooge's own canary gate exists to catch.

**Same wall as headroom.** scrooge's layers (terse reinforcement per turn,
read-ledger dedup, prefix-guard) are **multi-turn** mechanisms. A one-shot headless
A/B can't exercise them and the $ is drowned in cache noise.

## Meta-finding: the single-shot harness is the wrong instrument

On single-shot `claude -p`: **headroom = 0%** (prefix_frozen), **scrooge terse =
+0.2% output** (null). Neither produces a valid saving — not because they don't work,
but because the harness can't trigger their multi-turn mechanisms and its $ is
dominated by cache variance. This *is* scrooge's thesis: microbenchmarks mislead;
measure the real multi-turn bill.

## 3. Output-lane tools barely move coding bills

On read-heavy coding tasks the bill is dominated by tool-result **input**, not
output — so terse/caveman (output-lane) that saved 14–18% on Q&A drop to −2%/−3%.

See [docs/coding-task-results.md](coding-task-results.md).

## 4. scrooge audit of the real bill

- Bill: **$15,937** (API-equiv), 8,994 sessions, 47 projects.
- Streams: **cacheRead 43% · cacheWrite 42% · output 11.5% · freshInput 2.8%** —
  i.e. **86% is cache**, which no single-stream compressor safely touches.
- Provably-avoidable, accuracy-safe: **$41 (0.3%)**.
- Advisory frontier — unexplained `cache_create`: **$2,243 (14.1%)**. Real money,
  but not blindly compressible; the win is in multi-turn cache dynamics
  (read-ledger dedup, prefix stability, subagent handoff).

## The through-line

Every layer shares one DNA: **route/compress low → verify → escalate only if needed.**

| layer | product | axis | verified? | number |
|-------|---------|------|-----------|--------|
| API / per-call | **Nadir** | which model runs | yes | −60% |
| agent harness | **scrooge** | Claude Code/Codex spend | yes | honest measure + gate |
| sub-layer | caveman | output tokens | no | ~65% output |
| anti-pattern | headroom | input tokens | no | **+17% / 0% — proof you need the gate** |

- **Nadir** carries the big, real number (−60%) because it changes *which model runs*.
- **scrooge** carries the *truth + the accuracy gate* — measures the real bill and
  blocks anything that hurts quality.
- **headroom** is the cautionary tale: an unverified compressor that netted **+17%**
  on cache-heavy work and **0%** on coding — exactly why the verifier gate is the
  whole product.

## Caveat on the coding-task N=12 numbers

The per-prompt raw records for the coding-task run were not preserved to disk in
this session; the table in [coding-task-results.md](coding-task-results.md) is
transcribed from the live run. The Q&A A/B, headroom ledger, and scrooge audit are
all backed by committed raw files and are re-runnable via `scripts/`.
