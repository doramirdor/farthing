<div align="center">

# ▲ NADIR·BENCH

### Cut your AI costs, not your accuracy.

**An open, reproducible benchmark of token-cost tools on real Claude Code work.**
Priced at the bill, not at a dashboard.

`LOWEST VIABLE MODEL · VERIFIED BY NADIR`

[getnadir.com](https://getnadir.com) · [The receipts](#-the-receipts) · [Why compression loses](#why-compression-loses-on-claude-code) · [Reproduce](REPRODUCE.md)

</div>

---

> **Nadir routes every prompt to its leanest capable model and verifies the answer
> before you see it — 60% cheaper, 98% of always-Opus quality.**
> This repo is the other half of that thesis: we measured the *token-shaving*
> tools everyone reaches for first, on real Claude Code sessions, and priced the
> **actual bill**. They don't just fail to help — one of them **triples it while
> its own dashboard reports a saving.**

---

## ▮ The receipts

Same real task — add a method to **expressjs/express**, a multi-turn Claude Code
session on Opus — three arms, every turn metered.

| arm | session cost | vs baseline | cache_create | what it does |
|-----|-------------:|------------:|-------------:|--------------|
| **baseline** | `$0.730` | — | 40k | plain Claude Code |
| **scrooge** | `$0.643` | **−12%** ✅ | 37k (flat) | measures the bill, never touches the cached prefix |
| **headroom** | `$2.788` | **+282%** ❌ | 337k (**8×**) | rewrites the prefix to "compress" → busts the cache |

> headroom **genuinely compressed** (its `/stats`: 41% avg, 86k tokens removed) and
> reported a **−16% saving.** The **real bill rose 45–282%.** Self-reported savings
> were **the wrong sign.**

<div align="center">

### PROOF, NOT PROMISES

| `−12%` | `+282%` | `0%` |
|:---:|:---:|:---:|
| **scrooge** — cache-safe, real | **headroom** — cache-bust, real bill | **dashboard truth** — its ledger said it *saved* |

</div>

---

## Why compression loses on Claude Code

Claude Code's cost model **is** prompt caching. Three price lanes (Opus, per 1M tok):

| lane | price | vs base |
|------|------:|--------:|
| cache **read** (stable prefix) | `$1.50` | 0.1× |
| fresh **input** | `$15` | 1× |
| cache **create** (rewrite) | `$18.75` | **12× the read lane** |

A stable prefix is served from cache — nearly free. **Compression rewrites the
prefix to shrink it**, which invalidates the cache from the edit point on, forcing
Claude to **re-create** the whole downstream context at 12× the price.

- **headroom** deletes ~15–41% of some tokens (its dashboard counts this as saved)
  but shoves the survivors from the `$1.50` lane into the `$18.75` lane (its
  dashboard never counts this). Net: **bill up 45–282%.**
- **scrooge** never touches the cached prefix. It trims the **output** lane
  (terse-output) and blocks **byte-identical re-reads** (read-ledger) — cache-safe
  savings — while *measuring* cache churn instead of causing it. Net: **−12%,
  cache_create flat.**

> Same axis — `cache_create`. headroom **manufactures** it; scrooge **measures and
> avoids** it. That is the whole idea.

---

## ▮ The full study

Every number below is reproducible from [`REPRODUCE.md`](REPRODUCE.md).

### Agentic matrix — 96 runs, tools ON ([results/matrix.md](results/matrix.md))
4 arms × 8 add/fix/change tasks × N=3 on a real calculator project, accuracy-gated.

| arm | median $/task | vs baseline | accuracy |
|-----|-------------:|------------:|---------:|
| baseline | $0.311 | — | 23/24 |
| scrooge terse | $0.296 | **−5%** | 24/24 |
| caveman | $0.364 | **+17%** | 24/24 |
| headroom | $0.581 | **+87%** | 24/24 |

### Real project — monitored express sessions ([results/express_real_project.md](results/express_real_project.md))
| task | baseline | headroom | actual bill | headroom dashboard |
|------|--------:|---------:|:-----------:|:------------------:|
| trace | $0.947 | $1.375 | **+45%** | "saved −3%" |
| feature | $0.687 | $1.087 | **+58%** | "saved −11%" |
| bugfix | $1.293 | $2.578 | **+99%** | "saved −7%" |

### Faithful re-runs ([results/faithful_arms.md](results/faithful_arms.md))
Objections addressed — real caveman plugin (+17%), real multi-turn + token-mode
headroom — both confirmed the result.

Full write-up: [docs/FINDINGS.md](docs/FINDINGS.md).

---

## The tools, placed

| tool | axis it attacks | verdict on Claude Code coding |
|------|-----------------|-------------------------------|
| **[Nadir](https://getnadir.com)** | *which model runs* (route + verify) | **−60%**, 98% quality — the axis that actually moves the bill |
| **scrooge** | *measures the whole bill; cache-safe layers* | **−5% to −12%**, accuracy-gated, never busts cache |
| **caveman** | *output tokens* | **+16–17%** — cuts output (~1% of a coding bill) but adds per-turn injection |
| **headroom** | *input tokens (compress)* | **+45% to +282%** — compresses, but rewriting the prefix busts the cache |

> The savings live at **model choice** (Nadir) and **honest measurement + cache
> discipline** (scrooge) — never at token-shaving a cache-dominated bill.

---

## Reproduce it yourself

See [**REPRODUCE.md**](REPRODUCE.md). One command each; every run edits only
throwaway `/tmp` copies and costs real Opus tokens on your own account.

```bash
git clone --depth 1 https://github.com/expressjs/express.git /tmp/express-bench
( cd /tmp/express-bench && npm install )
headroom proxy --port 8787 --mode token &
bash benchmark/express_session.sh baseline feature
bash benchmark/express_session.sh headroom feature   # compare totals, not its dashboard
```

---

## Layout

```
benchmark/        the harnesses (run_matrix, express_session, multiturn, run_bench)
bench-calculator/ the calculator target repo (8 tasks, accuracy gate)
results/          computed tables + raw CSVs (synthetic tasks only)
docs/             FINDINGS + method
index.html        getnadir-styled landing page (GitHub Pages)
```

## Method & honesty

- Compare the **session total** (sum of per-turn `total_cost_usd`), never a tool's
  own dashboard — the express test exists because those diverge.
- Cost is noisy (5-min cache TTL, agent nondeterminism): N≥3, median, interleave arms.
- Compare cost **only among runs that passed** the accuracy gate.
- The single-shot Q&A A/B was run on a **private** corpus; raw prompts are **not**
  included in this public repo. Only aggregate numbers remain.

<div align="center">

**Built alongside [Nadir](https://getnadir.com) — the verifier-gated LLM router.**
`route lower · verify · escalate only if needed`

</div>
