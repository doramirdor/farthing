// Parser: converts a token stream into Reverse Polish Notation (RPN) using the
// shunting-yard algorithm, then the evaluator consumes the RPN. Handles binary
// operators with precedence/associativity, parentheses, unary minus, named
// constants, and single-argument function calls.

import { BINARY_OPS, isBinaryOp, isFunction, isConstant } from './operations.js';

// Represent unary minus internally as the token 'u-'.
const UNARY_MINUS = 'u-';

function precedenceOf(sym) {
  if (sym === UNARY_MINUS) return 4; // binds tighter than ^ 's operands
  return BINARY_OPS[sym].precedence;
}

function assocOf(sym) {
  if (sym === UNARY_MINUS) return 'right';
  return BINARY_OPS[sym].assoc;
}

// Decide whether a '-' at position `idx` is unary (negation) or binary
// (subtraction), based on the previous meaningful token.
function isUnaryContext(prev) {
  if (!prev) return true;
  if (prev.type === 'op') return true;
  if (prev.type === 'paren' && prev.value === '(') return true;
  if (prev.type === 'comma') return true;
  return false;
}

export function toRPN(tokens) {
  const output = [];
  const stack = [];
  // Parallel stack of argument counts, one entry per currently-open function
  // call. Pushed when a call's '(' opens, incremented on each comma, popped
  // and attached to the function token when the call's ')' closes.
  const argcStack = [];

  for (let i = 0; i < tokens.length; i++) {
    const tok = tokens[i];
    const prev = tokens[i - 1];

    if (tok.type === 'number') {
      output.push(tok);
    } else if (tok.type === 'ident') {
      if (isFunction(tok.value)) {
        stack.push({ type: 'func', value: tok.value });
      } else if (isConstant(tok.value)) {
        output.push({ type: 'const', value: tok.value });
      } else {
        throw new Error(`Unknown identifier '${tok.value}'`);
      }
    } else if (tok.type === 'op') {
      let sym = tok.value;
      if (sym === '-' && isUnaryContext(prev)) {
        sym = UNARY_MINUS;
      }
      while (stack.length) {
        const top = stack[stack.length - 1];
        if (top.type !== 'op') break;
        const higher = precedenceOf(top.value) > precedenceOf(sym);
        const equalLeft =
          precedenceOf(top.value) === precedenceOf(sym) && assocOf(sym) === 'left';
        if (higher || equalLeft) {
          output.push(stack.pop());
        } else {
          break;
        }
      }
      stack.push({ type: 'op', value: sym });
    } else if (tok.type === 'paren' && tok.value === '(') {
      // A '(' that immediately follows a function name opens a call; start
      // counting its arguments (assume one until a comma proves otherwise).
      const top = stack[stack.length - 1];
      const isCall = !!(top && top.type === 'func');
      if (isCall) argcStack.push(1);
      stack.push({ type: 'paren', value: '(', isCall });
    } else if (tok.type === 'paren' && tok.value === ')') {
      while (stack.length && !(stack[stack.length - 1].type === 'paren')) {
        output.push(stack.pop());
      }
      if (!stack.length) throw new Error('Mismatched parentheses');
      const open = stack.pop(); // discard '('
      // If this paren opened a call, pop the function to output with the arg
      // count we accumulated across its commas.
      if (open.isCall) {
        const argc = argcStack.pop();
        const fn = stack.pop();
        output.push({ type: 'func', value: fn.value, argc });
      }
    } else if (tok.type === 'comma') {
      // Argument separator: flush until '(' and count one more argument for
      // the innermost open call.
      while (stack.length && !(stack[stack.length - 1].type === 'paren')) {
        output.push(stack.pop());
      }
      if (!argcStack.length) throw new Error('Comma outside function call');
      argcStack[argcStack.length - 1]++;
    }
  }

  while (stack.length) {
    const top = stack.pop();
    if (top.type === 'paren') throw new Error('Mismatched parentheses');
    output.push(top);
  }
  return output;
}
