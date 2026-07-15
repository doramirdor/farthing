// Operation registry: binary operators (with precedence + associativity) and
// named functions. The parser and evaluator both read from here, so adding a
// new operator or function is a single-file change.

export const BINARY_OPS = {
  '+': { precedence: 1, assoc: 'left', apply: (a, b) => a + b },
  '-': { precedence: 1, assoc: 'left', apply: (a, b) => a - b },
  '*': { precedence: 2, assoc: 'left', apply: (a, b) => a * b },
  '/': {
    precedence: 2,
    assoc: 'left',
    apply: (a, b) => {
      if (b === 0) throw new Error('Division by zero');
      return a / b;
    },
  },
  '%': {
    precedence: 2,
    assoc: 'left',
    apply: (a, b) => {
      if (b === 0) throw new Error('Modulo by zero');
      return a % b;
    },
  },
  '^': { precedence: 3, assoc: 'right', apply: (a, b) => Math.pow(a, b) },
};

export const CONSTANTS = {
  pi: Math.PI,
  e: Math.E,
};

// Named functions callable as `name(arg)`. Most are unary; `max` takes two
// arguments. The parser does not yet emit multi-argument calls, so `max` is
// only reachable once the parser tracks argument counts across commas.
export const FUNCTIONS = {
  abs: (x) => Math.abs(x),
  floor: (x) => Math.floor(x),
  ceil: (x) => Math.ceil(x),
  round: (x) => Math.round(x),
  max: (a, b) => Math.max(a, b),
};

export function isBinaryOp(sym) {
  return Object.prototype.hasOwnProperty.call(BINARY_OPS, sym);
}

export function isFunction(name) {
  return Object.prototype.hasOwnProperty.call(FUNCTIONS, name);
}

export function isConstant(name) {
  return Object.prototype.hasOwnProperty.call(CONSTANTS, name);
}
