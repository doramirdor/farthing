# Faithful arms — correcting the two unfairness concerns

The matrix used `--append-system-prompt` proxies for caveman/scrooge and
single-shot `-p` for headroom. Two objections were valid, so both arms were
re-run faithfully. **Both corrections confirmed the matrix conclusions.**

## 1. Caveman — real plugin (not an appended prompt)

Ran the actual `caveman@caveman` plugin (toggled on in `enabledPlugins`) vs a
clean baseline (plugin off), 8 tasks × N=3. Raw: [`caveman_plugin_raw.csv`](caveman_plugin_raw.csv).

| | mean median $/task | vs baseline | mean output tokens |
|--|--:|--:|--:|
| baseline | $0.311 | — | 2,032 |
| caveman (append proxy) | $0.360 | +15.9% | 2,940 |
| **caveman (real plugin)** | **$0.364** | **+17.0%** | **1,776** |

- The real plugin **does cut output** (2,032 → 1,776, −13%) — it works as designed.
- It **still costs +17%**, because on agentic coding output is ~1% of the bill,
  while caveman's per-turn style injection *adds* input tokens across many turns.
- The append-proxy's +15.9% was not an artifact — the faithful plugin lands +17.0%.
  **Conclusion stands: caveman raises the cost of agentic coding.** Accuracy 24/24.

## 2. Headroom — real multi-turn session (not single-shot)

Its niche is long multi-turn sessions (its compression only touches the uncached
"live zone"). So we ran a real **6-turn chained `--resume` session** (read files →
edit across tokenizer/parser/evaluator → add test → run/fix) as baseline (direct)
vs headroom (proxy). Raw: [`headroom_multiturn_raw.csv`](headroom_multiturn_raw.csv).

| | 6-turn session cost |
|--|--:|
| baseline | **$1.550** |
| headroom | **$1.768** (**+14.0%**) |

**headroom's own `/stats` over the 21 API requests of its session:**

```
requests_compressed: 0        avg_compression_pct: 0%      tokens_removed: 0
uncompressed: { prefix_frozen: 21 }          # ALL requests frozen, none compressed
input before/after: 179,329 / 179,329        # optimizer changed nothing
cost: without_headroom $1.33 / with_headroom $1.33   savings: 0%
tip (from headroom): "Most requests are prefix-frozen. Set HEADROOM_MODE=token
                      to compress frozen messages…"   # i.e. bust the cache
```

Even given its real multi-turn niche, headroom in default (`cache`) mode:
- compressed **0%** — every request was `prefix_frozen`;
- realized **0** token savings (`input_original == input_optimized` on every request);
- still cost **+14%** on the session.

Its one active transform was `tool_search_deferral` — claiming 768k "tool-schema
tokens saved". But (a) the request logs show `input_optimized == input_original`,
so those tokens were **not actually removed** from what was sent, and (b) Claude
Code **already** defers tool schemas itself, so it's double-counting a saving the
client already performs.

### Why headroom can't win here (the honest, general statement)

headroom's two levers are **already handled by Claude Code**: prompt caching
(headroom freezes the cached prefix → nothing to compress) and tool-schema
deferral (the client already does it). Its only remaining lever is
`HEADROOM_MODE=token`, which compresses the **cached** prefix — busting the cache,
which is the **+87%** the matrix measured. headroom would help a naive API app
that does *neither* caching nor tool-deferral; against Claude Code it is
redundant-to-harmful. **The stars are real — earned on that other workload.**
