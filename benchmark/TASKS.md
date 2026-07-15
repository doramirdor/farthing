# Benchmark tasks — bench-calculator

8 agentic coding tasks over `bench-calculator/`. Each forces real `Read` + `Edit`
work across multiple files and has a **verifiable acceptance check** (the accuracy
gate). Run every task from the pinned `BASE_SHA` with `reset_repo` first.

Prompt handed to the agent = the **Task** line. Acceptance = the **Check** passes
AND `npm test` stays green (no regressions).

| id | type | files it must touch | Task (agent prompt) | Check |
|----|------|---------------------|---------------------|-------|
| T1 | add | operations.js, test | "Add a `sqrt` function to the calculator so `sqrt(9)` returns 3. Add a test." | `calculate('sqrt(9)') === 3` |
| T2 | add | operations.js, test | "Add a `tau` constant equal to 2*pi so `calculate('tau')` works. Add a test." | `abs(calculate('tau') - 2*Math.PI) < 1e-9` |
| T3 | add | operations.js, parser.js, evaluator.js, test | "Add a two-argument `max(a, b)` function, e.g. `max(3, 7)` returns 7. Functions are currently single-arg, so update tokenizer/parser/evaluator as needed." | `calculate('max(3, 7)') === 7` |
| T4 | fix | tokenizer.js, test | "The tokenizer rejects scientific notation like `1e3`. Add support so `calculate('1e3')` returns 1000." | `calculate('1e3') === 1000` |
| T5 | fix | parser.js or evaluator.js, test | "`calculate('2 ^ -2')` should return 0.25 but currently throws or is wrong. Fix negative exponents." | `calculate('2 ^ -2') === 0.25` |
| T6 | change | operations.js, calculator.js, test | "Add integer-division operator `//` (floor division) with the same precedence as `/`, so `7 // 2` is 3." | `calculate('7 // 2') === 3` |
| T7 | change | calculator.js, test | "Add an `undo()` method to the `Calculator` class that removes the last history entry and returns it." | `c.eval('1+1'); c.undo().result === 2 && c.history.length === 0` |
| T8 | add | index.js, calculator.js, test | "Add a `calculateAll(expressions)` export that takes an array of strings and returns an array of results, skipping (null) any that throw." | `calculateAll(['2+2','1/0','3*3'])` deep-equals `[4, null, 9]` |

## Difficulty spread (for token load)

- **Light reads** (T1, T2): one registry file. Small input.
- **Cross-file** (T3, T5, T6): tokenizer → parser → evaluator chain. Big reads,
  most representative of real coding cost.
- **Facade/API** (T7, T8): calculator.js / index.js.

## Reset helper

```bash
BASE_SHA=$(cat /tmp/BASE_SHA)
reset_repo() { git -C bench-calculator reset --hard "$BASE_SHA" -q && git -C bench-calculator clean -fdq; }
```

## Arms (per task, cold session, N>=3, median)

| arm | launch |
|-----|--------|
| baseline | `claude -p "$TASK" --allowedTools "Read,Edit,Bash" --output-format json` |
| headroom | `ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude -p "$TASK" --allowedTools "Read,Edit,Bash" --output-format json` |
| scrooge  | scrooge hooks enabled, then plain `claude -p ...` |
| caveman  | caveman plugin active, then plain `claude -p ...` |

Record per run: `cost_usd, input, cache_create, cache_read, output, accuracy(PASS/FAIL)`.
Compare cost **only among runs that passed**. Cross-check each tool's own ledger
(`curl localhost:8787/stats`, `scrooge audit --session`).
