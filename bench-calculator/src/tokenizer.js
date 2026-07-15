// Tokenizer: turns a raw expression string into a flat token stream.
// Token shapes: { type: 'number', value } | { type: 'op', value } |
//               { type: 'paren', value: '(' | ')' } | { type: 'ident', value }

const OPERATORS = new Set(['+', '-', '*', '/', '%', '^']);

function isDigit(ch) {
  return ch >= '0' && ch <= '9';
}

function isIdentStart(ch) {
  return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch === '_';
}

function isIdentPart(ch) {
  return isIdentStart(ch) || isDigit(ch);
}

// Read a number literal starting at index i. Supports integers and decimals.
// Returns [token, nextIndex].
function readNumber(src, i) {
  let start = i;
  let seenDot = false;
  while (i < src.length) {
    const ch = src[i];
    if (isDigit(ch)) {
      i++;
    } else if (ch === '.' && !seenDot) {
      seenDot = true;
      i++;
    } else {
      break;
    }
  }
  const raw = src.slice(start, i);
  return [{ type: 'number', value: Number(raw), raw }, i];
}

// Read an identifier (function name or constant like `pi`).
function readIdent(src, i) {
  let start = i;
  while (i < src.length && isIdentPart(src[i])) {
    i++;
  }
  return [{ type: 'ident', value: src.slice(start, i) }, i];
}

export function tokenize(src) {
  const tokens = [];
  let i = 0;
  while (i < src.length) {
    const ch = src[i];
    if (ch === ' ' || ch === '\t' || ch === '\n') {
      i++;
      continue;
    }
    if (isDigit(ch) || (ch === '.' && isDigit(src[i + 1]))) {
      const [tok, next] = readNumber(src, i);
      tokens.push(tok);
      i = next;
      continue;
    }
    if (isIdentStart(ch)) {
      const [tok, next] = readIdent(src, i);
      tokens.push(tok);
      i = next;
      continue;
    }
    if (OPERATORS.has(ch)) {
      tokens.push({ type: 'op', value: ch });
      i++;
      continue;
    }
    if (ch === '(' || ch === ')') {
      tokens.push({ type: 'paren', value: ch });
      i++;
      continue;
    }
    if (ch === ',') {
      tokens.push({ type: 'comma', value: ',' });
      i++;
      continue;
    }
    throw new Error(`Unexpected character '${ch}' at position ${i}`);
  }
  return tokens;
}
