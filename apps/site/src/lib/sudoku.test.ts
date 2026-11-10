import assert from 'node:assert/strict';
import { test } from 'node:test';
import { conflicts, formatTime, isSolved, puzzle, solution } from './sudoku.ts';

// Takrorlanadigan sinov uchun oddiy tasodifiy generator.
function seeded(seed: number): () => number {
  return () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return seed / 4294967296;
  };
}

test('Sudoku: har bir yechim qoidaga mos', () => {
  for (let seed = 1; seed <= 50; seed++) assert.equal(isSolved(solution(seeded(seed))), true);
});

test('Sudoku: boshqotirma yechimdan olinadi va kerakli kataklar bo\'sh', () => {
  const easy = puzzle('easy', seeded(7));
  const hard = puzzle('hard', seeded(7));
  assert.equal(easy.filter((v) => v === 0).length, 38);
  assert.equal(hard.filter((v) => v === 0).length, 50);
  assert.equal(conflicts(easy).size, 0);
  assert.equal(isSolved(easy), false);
});

test('Sudoku: takror raqam ikkala katakda ham belgilanadi', () => {
  const board = solution(seeded(3));
  const swapped = [...board];
  swapped[1] = board[0];
  const bad = conflicts(swapped);
  assert.equal(bad.has(0), true);
  assert.equal(bad.has(1), true);
  assert.equal(isSolved(swapped), false);
});

test('Sudoku: vaqt daqiqa:soniya ko\'rinishida', () => {
  assert.equal(formatTime(0), '0:00');
  assert.equal(formatTime(125), '2:05');
});
