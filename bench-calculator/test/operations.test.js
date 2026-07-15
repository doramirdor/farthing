import { test } from 'node:test';
import assert from 'node:assert/strict';
import { BINARY_OPS, FUNCTIONS, isBinaryOp, isFunction, isConstant } from '../src/operations.js';

test('binary op registry', () => {
  assert.ok(isBinaryOp('+'));
  assert.ok(isBinaryOp('^'));
  assert.ok(!isBinaryOp('$'));
  assert.equal(BINARY_OPS['*'].apply(3, 4), 12);
  assert.equal(BINARY_OPS['^'].assoc, 'right');
});

test('functions registry', () => {
  assert.ok(isFunction('abs'));
  assert.ok(!isFunction('nope'));
  assert.equal(FUNCTIONS.floor(9.9), 9);
});

test('constants registry', () => {
  assert.ok(isConstant('pi'));
  assert.ok(isConstant('e'));
  assert.ok(!isConstant('tau'));
});
