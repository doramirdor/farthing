// Calculator facade: ties tokenizer -> parser -> evaluator into one entry
// point, plus a small stateful class with a running-memory register.

import { tokenize } from './tokenizer.js';
import { toRPN } from './parser.js';
import { evalRPN } from './evaluator.js';

// Evaluate a single expression string and return the numeric result.
export function calculate(expr) {
  if (typeof expr !== 'string' || expr.trim() === '') {
    throw new Error('Expression must be a non-empty string');
  }
  const tokens = tokenize(expr);
  const rpn = toRPN(tokens);
  return evalRPN(rpn);
}

// Stateful calculator with a memory register and an evaluation history.
export class Calculator {
  constructor() {
    this.memory = 0;
    this.history = [];
  }

  eval(expr) {
    const result = calculate(expr);
    this.history.push({ expr, result });
    return result;
  }

  memoryStore(value) {
    this.memory = value;
  }

  memoryRecall() {
    return this.memory;
  }

  memoryClear() {
    this.memory = 0;
  }

  clearHistory() {
    this.history = [];
  }
}
