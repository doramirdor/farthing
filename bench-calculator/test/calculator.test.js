import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calculate, Calculator } from '../src/calculator.js';

test('basic arithmetic', () => {
  assert.equal(calculate('2 + 3'), 5);
  assert.equal(calculate('10 - 4'), 6);
  assert.equal(calculate('6 * 7'), 42);
  assert.equal(calculate('20 / 5'), 4);
});

test('precedence and parentheses', () => {
  assert.equal(calculate('2 + 3 * 4'), 14);
  assert.equal(calculate('(2 + 3) * 4'), 20);
  assert.equal(calculate('2 * (3 + 4) - 1'), 13);
});

test('exponent is right-associative', () => {
  assert.equal(calculate('2 ^ 3'), 8);
  assert.equal(calculate('2 ^ 2 ^ 3'), 256); // 2^(2^3)
});

test('unary minus', () => {
  assert.equal(calculate('-5 + 3'), -2);
  assert.equal(calculate('3 * -2'), -6);
  assert.equal(calculate('-(4 + 1)'), -5);
});

test('decimals and modulo', () => {
  assert.equal(calculate('1.5 + 2.5'), 4);
  assert.equal(calculate('10 % 3'), 1);
});

test('constants and functions', () => {
  assert.ok(Math.abs(calculate('pi') - Math.PI) < 1e-9);
  assert.equal(calculate('abs(-7)'), 7);
  assert.equal(calculate('floor(3.9)'), 3);
  assert.equal(calculate('ceil(3.1)'), 4);
  assert.equal(calculate('round(2.5)'), 3);
  assert.equal(calculate('max(3, 7)'), 7);
});

test('division by zero throws', () => {
  assert.throws(() => calculate('1 / 0'), /Division by zero/);
});

test('stateful calculator memory + history', () => {
  const c = new Calculator();
  assert.equal(c.eval('2 + 2'), 4);
  c.memoryStore(c.eval('10 * 10'));
  assert.equal(c.memoryRecall(), 100);
  assert.equal(c.history.length, 2);
  c.memoryClear();
  assert.equal(c.memoryRecall(), 0);
});
