# Real project: monitored Claude Code sessions on express

Fresh clone of [expressjs/express](https://github.com/expressjs/express) (real,
cross-referenced `lib/*.js`). Three realistic multi-turn Claude Code sessions —
**trace** (read-only), **feature** (add `res.sendError`), **bugfix** (harden
`res.location`) — each run as baseline vs headroom (**token mode**, its compressing
default), every turn monitored. Raw: [`express_sessions_raw.csv`](express_sessions_raw.csv).

## Session totals

| task | baseline | headroom (token) | actual bill | headroom's own `/stats` claims |
|------|--------:|-----------------:|------------:|-------------------------------:|
| trace (read-only) | $0.947 | $1.375 | **+45%** | compressed 15.4%, removed 5,660 tok, "saved −3%" |
| feature | $0.687 | $1.087 | **+58%** | compressed 16.7%, removed 43,724 tok, "saved −11%" |
| bugfix | $1.293 | $2.578 | **+99%** | compressed 15.3%, removed 52,455 tok, "saved −7%" |

## The dashboard inversion (the key result)

On real express code headroom token-mode **genuinely compressed** — 15–17% average,
up to **52,455 tokens removed** in one session (far more than the toy calculator).
So "it doesn't reduce tokens" is **false — it does.**

But its dashboard reports a **3–11% saving** while the **actual bill rose 45–99%.**
The self-reported number isn't just optimistic — it's **inverted**.

### Why — the per-turn monitor shows it

Mean per turn across all sessions:

| arm | fresh_input | **cache_create** |
|-----|-----------:|------------------:|
| baseline | 1,719 | **11,480** |
| headroom | 7,627 | **34,875** (3×) |

Every time headroom rewrites a message to compress it, the **prompt prefix changes**,
so Claude Code must **re-cache the entire downstream context** — `cache_create`,
billed at ~1.25× the input rate. headroom counts the ~15% of message tokens it
removed as "saved," but is **blind to the 3× cache-write penalty it triggers**.
Removing 15% of a small live-zone slice while tripling cache_create on a
cache-dominated bill is a large net loss.

(Also visible: `fresh_input` 1.7k → 7.6k from headroom's turn-1 `tool_search`
deferral, and one degenerate `$0` turn in the bugfix session — instability on top
of the cache cost.)

## Bottom line

This is the cleanest confirmation in the whole study, on real cross-referenced code:

- headroom **does** compress (real, ~15%).
- Its **dashboard reports a saving** (−3% to −11%).
- The **real bill rises 45–99%**, because compressing the prefix triples cache_create
  — a cost the tool's own accounting never sees.
- **Self-reported per-stream savings ≠ the bill.** Here they're not merely smaller,
  they're the wrong sign. That is exactly the failure mode scrooge exists to catch:
  measure the whole bill, not one stream's dashboard.
