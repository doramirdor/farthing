// Public entry point + tiny CLI.
//   node src/index.js "2 + 3 * 4"

import { calculate, Calculator } from './calculator.js';

export { calculate, Calculator };
export { tokenize } from './tokenizer.js';
export { toRPN } from './parser.js';
export { evalRPN } from './evaluator.js';

// Run as a CLI only when invoked directly.
const invokedDirectly = process.argv[1] && process.argv[1].endsWith('index.js');
if (invokedDirectly) {
  const expr = process.argv.slice(2).join(' ');
  if (!expr) {
    console.error('usage: node src/index.js "<expression>"');
    process.exit(1);
  }
  try {
    console.log(calculate(expr));
  } catch (err) {
    console.error('error:', err.message);
    process.exit(1);
  }
}
