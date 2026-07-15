# Full matrix — 4 arms × 8 tasks × N=3 (Opus, agentic, tools ON)

Real `claude -p` agent runs on `bench-calculator` (Read/Edit/Bash). Median $ of
PASSING runs only (accuracy = `npm test` green + task gate). Caveman plugin was
globally disabled during the run; caveman/scrooge arms inject their output layer
via `--append-system-prompt`; headroom routes through its proxy.

## Median $ per task

| task | baseline | headroom | scrooge | caveman |
|--|--|--|--|--|
| T1 | $0.296 | $0.525 | $0.313 | $0.290 |
| T2 | $0.330 | $0.578 | $0.313 | $0.358 |
| T3 | $0.388 | $0.556 | $0.390 | $0.547 |
| T4 | $0.260 | $0.769 | $0.224 | $0.253 |
| T5 | $0.421 | $0.725 | $0.426 | $0.697 |
| T6 | $0.330 | $0.432 | $0.295 | $0.322 |
| T7 | $0.189 | $0.573 | $0.190 | $0.187 |
| T8 | $0.273 | $0.490 | $0.215 | $0.227 |

## Arm summary

| arm | mean median $/task | vs baseline | accuracy |
|--|--|--|--|
| baseline | $0.311 | +0.0% | 23/24 (96%) |
| headroom | $0.581 | +86.8% | 24/24 (100%) |
| scrooge | $0.296 | -4.8% | 24/24 (100%) |
| caveman | $0.360 | +15.9% | 24/24 (100%) |

## Where the tokens went (mean/run, PASS)

| arm | fresh_input | cache_read |
|--|--|--|
| baseline | 6,231 | 191,364 |
| headroom | 39,204 | 230,479 |
| scrooge | 6,194 | 185,985 |
| caveman | 6,265 | 216,461 |

**cache_read is ~30× fresh_input** — the bill is cache-dominated even on coding.
headroom's proxy inflates fresh_input 6k→39k (6.3×) by rewriting the payload and
busting cache → **+87%**. Output-lane caveman **+16%** (terse output but more/noisier
agent turns). scrooge terse **−5%** (only arm that saved; accuracy intact).
