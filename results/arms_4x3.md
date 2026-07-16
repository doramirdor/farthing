# 4 arms × 3 reps — the load-bearing experiment

Real multi-turn Claude Code sessions on a fresh `expressjs/express` clone. Six
identical prompts per session (read → fat-file read → find bug → fix + run tests →
add feature + run tests → review). Arms interleaved **within** each rep so cache
warmth can't favour one. Caveman disabled for the whole run; farthing's hooks
toggled on only for its arms. Raw: [`arms_4x3_raw.csv`](arms_4x3_raw.csv) (72 turns).

## Medians

| arm | sessions | median | vs baseline | cache_create (med) |
|-----|----------|-------:|------------:|-------------------:|
| baseline | $6.38, $10.37, $6.47 | $6.468 | — | 349,249 |
| **tokopt** | $6.77, $7.97, $6.96 | $6.956 | **+7.5%** | 365,609 |
| **farthing** | $6.56, $3.67, $4.62 | $4.623 | **−28.5%** | 274,839 |
| **combo** (farthing+tokopt) | $5.31, $3.83, $3.74 | $3.826 | **−40.9%** | 183,664 |

## Does it separate? (the honest part)

Session cost is **extremely noisy** — baseline alone ran $6.38 → $10.37, a **63%
swing on identical inputs**. So medians are not enough; we check separation.

| arm | runs below *every* baseline run | runs inside baseline range | verdict |
|-----|:---:|:---:|---|
| **combo** | **3/3** | 0/3 | **complete separation** |
| farthing | 2/3 | 1/3 | suggestive |
| tokopt | 0/3 | 3/3 | **indistinguishable from baseline** |

At n=3 vs n=3, complete separation is the **strongest result the sample size can
produce** (one-sided Mann-Whitney p≈0.05 — the floor at this n). It is
**suggestive, not proof**.

## The corroboration that makes it more than noise

An independent physical metric reproduces the cost ranking **exactly**:

```
by cost:          combo < farthing < baseline < tokopt
by cache_create:  combo < farthing < baseline < tokopt
```

Cost differences track a **mechanism** (less context carried → less cache_create →
lower bill), not a coin flip. Two independent measures agreeing is what separates
this from the single-run numbers we threw away.

## Why token-optimizer did nothing — the punchline

Its filter **provably works**: `npm test` output **69,037 → 1,333 chars (98%)`,
measured directly, zero noise. Yet it moved the session bill **not at all**.

Arithmetic explains it: the filter saves ~16k tokens per test run. The session bill
is **~3.9M cache_read tokens**. That's **0.4%**. A *perfect* filter on command
output cannot move a cache-dominated bill.

Same trap as headroom and caveman: **single-lane tools fighting a stream that
doesn't dominate.**

## Why farthing wins differently

`read-ledger` stops a redundant read from **entering context at all**. Smaller
context → **less carried on every subsequent turn** → compounding cuts to
`cache_read` *and* `cache_create`. It attacks the dominant stream itself rather
than a side channel — and, being cache-safe, it never pays headroom's rewrite
penalty.

> The only thing that moves a cache-dominated bill is **carrying less context** —
> not compressing it (busts the cache), not filtering side channels (too small),
> but **never putting the redundant thing in context in the first place.**

## What we claim / don't

**Claim:**
- combo **−41%**, farthing **−28.5%** — *in a 3-rep run, n=3, mechanism-corroborated,
  replication needed*. Not "saves 41%".
- token-optimizer: **no detectable effect** on Claude Code, despite a working filter.
- farthing is **cache-safe by construction** — an architectural guarantee, not a
  benchmark number.

**Don't claim:**
- Any tight savings %. The noise floor (±63%) is larger than most effects.
- Earlier single-run figures (tokopt −22.5%, farthing −12%) — **retracted**, they
  were noise.
