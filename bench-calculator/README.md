# bench-calculator

Expression calculator — the **benchmark target repo** for the agentic
coding-cost tests in this repository. Real multi-file code so that agent runs do
actual `Read` + `Edit` + `Bash` work (which is where headroom/scrooge/caveman
actually operate).

## Pipeline

```
"2 + 3 * 4"  ->  tokenizer.js  ->  parser.js (shunting-yard -> RPN)  ->  evaluator.js  ->  14
```

| file | role |
|------|------|
| `src/tokenizer.js`  | string → token stream |
| `src/operations.js` | registry: binary ops (precedence/assoc), functions, constants |
| `src/parser.js`     | tokens → RPN (handles parens, unary minus, funcs) |
| `src/evaluator.js`  | RPN → number |
| `src/calculator.js` | facade + stateful `Calculator` (memory, history) |
| `src/index.js`      | entry point + CLI |
| `test/`             | node built-in test runner — the **accuracy gate** |

## Use

```bash
node src/index.js "2 * (3 + 4) - 1"   # -> 13
npm test                              # accuracy gate; must be green at BASE_SHA
```

## Why it's a good benchmark target

- **Multi-file reads**: a task like "add a `sqrt` function" forces reading
  `operations.js` + `parser.js` + `evaluator.js` + tests → real input/cache load.
- **Verifiable**: every task has a test → hard accuracy gate (cheap-but-broken
  runs are discarded, not counted as savings).
- **Zero deps**: `node --test`, no install, deterministic baseline.

## Candidate benchmark tasks

See [`../benchmark/TASKS.md`](../benchmark/TASKS.md) for the add/fix/change task set.
