// Evaluator: consumes RPN produced by the parser and computes a numeric result.

import { BINARY_OPS, FUNCTIONS, CONSTANTS } from './operations.js';

const UNARY_MINUS = 'u-';

export function evalRPN(rpn) {
  const stack = [];

  for (const tok of rpn) {
    if (tok.type === 'number') {
      stack.push(tok.value);
    } else if (tok.type === 'const') {
      stack.push(CONSTANTS[tok.value]);
    } else if (tok.type === 'func') {
      const argc = tok.argc ?? 1;
      if (stack.length < argc) {
        throw new Error(`Function '${tok.value}' needs ${argc} argument(s)`);
      }
      // Operands were pushed left-to-right, so unshift as we pop to restore order.
      const args = [];
      for (let k = 0; k < argc; k++) args.unshift(stack.pop());
      stack.push(FUNCTIONS[tok.value](...args));
    } else if (tok.type === 'op') {
      if (tok.value === UNARY_MINUS) {
        if (stack.length < 1) throw new Error('Unary minus needs an operand');
        stack.push(-stack.pop());
        continue;
      }
      if (stack.length < 2) throw new Error(`Operator '${tok.value}' needs two operands`);
      const b = stack.pop();
      const a = stack.pop();
      stack.push(BINARY_OPS[tok.value].apply(a, b));
    } else {
      throw new Error(`Cannot evaluate token of type '${tok.type}'`);
    }
  }

  if (stack.length !== 1) {
    throw new Error('Malformed expression');
  }
  return stack[0];
}
