# Coding-task results (Opus, N=12)

> **Provenance: reported.** Transcribed from a live session run; each prompt reads
> 2–4 large files. Raw per-prompt records not preserved to disk (see FINDINGS
> caveat). Numbers below are the reported means.

| variant | N | mean $/prompt | bill vs base |
|---------|--:|--------------:|-------------:|
| baseline | 12 | $0.3653 | — |
| scrooge terse-output | 12 | $0.3581 | **−2%** |
| caveman full | 9\* | $0.3538 | **−3%** |
| headroom | — | 0% by its own `/stats` (`prefix_frozen`) | **0%** |

\*3 caveman rows failed during an Opus availability wobble.

## Interpretation

- On read-heavy coding tasks the bill is dominated by tool-result **input**, not
  output. The output-lane tools (terse-output, caveman) that saved **14–18% on
  Q&A** barely move it here: **−2% / −3%**.
- headroom *does* target input, but **cannot be measured in single-shot
  `claude -p`** — it freezes the cached prefix and only compresses the uncached
  multi-turn live zone. In a headless one-shot there is no live zone to compress,
  so `/stats` reports 0%.
- **Conclusion:** none of the single-lane output/input compressors help much in a
  headless A/B on coding work. The real money is in **multi-turn cache dynamics**
  (read-ledger dedup, prefix stability, subagent handoff) that only surface across
  a live session — precisely the gap scrooge targets, and precisely why a
  single-turn benchmark under-sells all of them.

## To get a real headroom coding number

Route an **interactive** (multi-turn) `claude` session through the proxy and read
`/stats` — it cannot be a scripted single-shot A/B:

```bash
headroom proxy --port 8787 &
ANTHROPIC_BASE_URL=http://localhost:8787 claude    # do real multi-turn work
curl -s localhost:8787/stats                       # read compression after
```
