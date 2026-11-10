import assert from 'node:assert/strict';
import { test } from 'node:test';
import { levelFor, options, pointsFor, question, rankFor } from './brain.ts';

function seeded(seed: number): () => number {
  return () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  };
}

test('Aql o\'yini: har savolda 4 xil variant va bittasi to\'g\'ri', () => {
  for (let seed = 1; seed <= 400; seed++) {
    const q = question(seed % 11, seeded(seed));
    assert.equal(q.options.length, 4, q.prompt);
    assert.equal(new Set(q.options).size, 4, q.prompt);
    assert.ok(q.options.includes(q.answer), q.prompt);
    assert.ok(q.options.every((n) => Number.isInteger(n) && n >= 0), q.prompt);
  }
});

test('Aql o\'yini: misol javobi to\'g\'ri hisoblangan', () => {
  for (let seed = 1; seed <= 300; seed++) {
    const q = question(seed % 11, seeded(seed));
    if (q.kind !== 'math') continue;
    const expr = q.prompt.replace(' = ?', '').replaceAll('×', '*').replaceAll('−', '-');
    assert.equal(Function(`return ${expr}`)(), q.answer, q.prompt);
  }
});

test('Aql o\'yini: ortiqcha son qolgan uchtasining umumiy bo\'luvchisiga bo\'linmaydi', () => {
  for (let seed = 1; seed <= 300; seed++) {
    const q = question(seed % 11, seeded(seed));
    if (q.kind !== 'odd') continue;
    const rest = q.options.filter((n) => n !== q.answer);
    const shared = [2, 3, 4, 5, 6, 7, 9, 10].filter((k) => rest.every((n) => n % k === 0));
    assert.ok(shared.some((k) => q.answer % k !== 0), `${q.options}`);
  }
});

test('Aql o\'yini: variantlar javobga yaqin va takrorlanmaydi', () => {
  const list = options(0, seeded(1));
  assert.equal(new Set(list).size, 4);
  assert.ok(list.includes(0));
});

test('Aql o\'yini: daraja, ochko va unvon', () => {
  assert.equal(levelFor(0), 0);
  assert.equal(levelFor(7), 2);
  assert.equal(levelFor(100), 10);
  assert.equal(pointsFor(0), 10);
  assert.equal(pointsFor(3), 30);
  assert.equal(pointsFor(9), 50);
  assert.equal(rankFor(0), 1);
  assert.equal(rankFor(250), 3);
  assert.equal(rankFor(1000), 4);
});
