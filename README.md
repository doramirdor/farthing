<div align="center">

# ▲ FARTHING

### The honest token meter for Claude Code. Count every farthing.

**Measure your real bill. Run only what pays. Prove accuracy didn't move —
without ever busting the cache.**

`accuracy-gated token control · part of` **[Nadir](https://getnadir.com)** · `LOWEST VIABLE MODEL · VERIFIED`

```bash
npx @getnadir/farthing audit      # decompose your real Claude Code bill
```

[getnadir.com](https://getnadir.com) · [The receipts](#-the-receipts) · [Why compression loses](#why-compression-loses-on-claude-code) · [Reproduce](REPRODUCE.md)

</div>

---

> **Farthing** is the cache-safe spend controller for Claude Code & Codex — from the
> team behind **[Nadir](https://getnadir.com)**, the verifier-gated LLM router.
> Nadir picks the leanest model and verifies the answer; farthing measures the
> **actual bill** and cuts it **without touching the cached prefix**.
>
> This repo is the proof. We benchmarked the *token-shaving* tools everyone reaches
> for first, on real Claude Code sessions, priced the **actual bill** — and put
> farthing head-to-head. One competitor **triples the bill while its own dashboard
> reports a saving.** farthing cuts it and never busts the cache.

---

## ▮ The receipts

Real multi-turn Claude Code sessions on a fresh **expressjs/express** clone, Opus,
6 identical prompts per session. **4 arms × 3 reps**, interleaved, every turn
metered. Full method + caveats: [`results/arms_4x3.md`](results/arms_4x3.md).

| arm | median session | vs baseline | cache_create | separation |
|-----|---------------:|------------:|-------------:|-----------:|
| **baseline** | `$6.468` | — | 349k | — |
| **combo** (farthing+tokopt) | `$3.826` | **−41%** | 184k | **3/3** ✅ |
| **farthing** | `$4.623` | **−28%** | 275k | 2/3 |
| **token-optimizer** | `$6.956` | +7.5% | 366k | 0/3 ✗ |
| **headroom** | — | **costs more, 10/10 trials** | **2.4–8×** ❌ | — |

> **Read these as directional, not exact.** Session cost is brutally noisy —
> baseline alone swung **$6.38 → $10.37 (63%) on identical inputs**. What makes the
> result credible isn't the median, it's that an independent metric reproduces the
> ranking exactly:
> ```
> by cost:          combo < farthing < baseline < tokopt
> by cache_create:  combo < farthing < baseline < tokopt
> ```

<div align="center">

### PROOF, NOT PROMISES

| `10/10` | `2.4–8×` | `0.4%` |
|:---:|:---:|:---:|
| **headroom** cost more in every trial | its `cache_create` inflation | what a **perfect** command-output filter is worth on a cache-dominated bill |

</div>

**The finding:** the only thing that moves a cache-dominated bill is **carrying less
context** — not compressing it (busts the cache), not filtering side channels (too
small), but **never putting the redundant thing in context in the first place.**

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
- **farthing** never touches the cached prefix. It trims the **output** lane
  (terse-output) and blocks **byte-identical re-reads** (read-ledger) — cache-safe
  savings — while *measuring* cache churn instead of causing it. Net: **−28% median
  (n=3, directional), cache_create down — never up.**

> Same axis — `cache_create`. headroom **manufactures** it; farthing **measures and
> avoids** it. That is the whole idea.

---

## ▮ The full study

Every number below is reproducible from [`REPRODUCE.md`](REPRODUCE.md).

### Agentic matrix — 96 runs, tools ON ([results/matrix.md](results/matrix.md))
4 arms × 8 add/fix/change tasks × N=3 on a real calculator project, accuracy-gated.

| arm | median $/task | vs baseline | accuracy | verdict |
|-----|-------------:|------------:|---------:|---------|
| baseline | $0.311 | — | 23/24 | — |
| farthing terse | $0.296 | −5% | 24/24 | *within noise* |
| caveman | $0.364 | +17% | 24/24 | *marginal* |
| headroom | $0.581 | **+87%** | 24/24 | **survives** |

Only headroom's **+87%** clears the noise floor here. The ±5% and +17% figures are
reported for completeness but are **not claims** — see [`results/arms_4x3.md`](results/arms_4x3.md)
for why session cost needs separation tests, not medians alone.

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
| **farthing** | *carry less context; cache-safe layers* | **−28% median (n=3, directional)** — cache-safe by construction, never busts cache |
| **caveman** | *output tokens* | **+17%** — cuts output (~1% of a coding bill) but adds per-turn injection |
| **token-optimizer** | *command output* | **no detectable effect** — its filter works (98% on `npm test`) but that's 0.4% of the bill |
| **headroom** | *input tokens (compress)* | **+45% to +282%** — compresses, but rewriting the prefix busts the cache |

> The savings live at **model choice** (Nadir) and **honest measurement + cache
> discipline** (farthing) — never at token-shaving a cache-dominated bill.

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
