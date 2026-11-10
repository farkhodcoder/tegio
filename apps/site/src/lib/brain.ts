// Kutish paytidagi aql o'yini: cheksiz, tasodifiy savollar, daraja javoblar bilan oshadi.
export type Kind = 'seq' | 'math' | 'odd' | 'missing';
export type Question = { kind: Kind; prompt: string; options: number[]; answer: number };

type Rand = () => number;

const int = (rand: Rand, min: number, max: number) => min + Math.floor(rand() * (max - min + 1));
const pick = <T>(rand: Rand, list: readonly T[]): T => list[Math.floor(rand() * list.length)];

function shuffle<T>(items: T[], rand: Rand): T[] {
  const list = [...items];
  for (let i = list.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [list[i], list[j]] = [list[j], list[i]];
  }
  return list;
}

/** To'g'ri javob va unga yaqin uchta noto'g'ri variant. */
export function options(answer: number, rand: Rand): number[] {
  const spread = Math.max(3, Math.round(Math.abs(answer) * 0.15));
  const set = new Set([answer]);
  for (let guard = 0; set.size < 4 && guard < 100; guard++) {
    const delta = int(rand, 1, spread) * (rand() < 0.5 ? -1 : 1);
    if (answer + delta >= 0) set.add(answer + delta);
  }
  for (let n = answer + 1; set.size < 4; n++) set.add(n);
  return shuffle([...set], rand);
}

function sequence(level: number, rand: Rand): Question {
  const rules = level < 3 ? ['add', 'mul'] : level < 6 ? ['add', 'mul', 'grow', 'alt'] : ['mul', 'grow', 'alt', 'square', 'fib'];
  const rule = pick(rand, rules);
  let terms: number[];
  switch (rule) {
    case 'add': {
      const start = int(rand, 1, 20);
      const step = int(rand, 2, 9 + level);
      terms = Array.from({ length: 5 }, (_, i) => start + step * i);
      break;
    }
    case 'mul': {
      const start = int(rand, 1, 4);
      const ratio = level < 4 ? 2 : pick(rand, [2, 3]);
      terms = Array.from({ length: 5 }, (_, i) => start * ratio ** i);
      break;
    }
    case 'grow': {
      // Farq har safar bittaga oshadi: 2, 3, 5, 8, 12, ...
      terms = [int(rand, 1, 10)];
      let step = int(rand, 1, 4);
      while (terms.length < 5) terms.push(terms[terms.length - 1] + step++);
      break;
    }
    case 'alt': {
      // Navbatma-navbat qo'shish va ayirish: +a, -b.
      const a = int(rand, 4, 9 + level);
      const b = int(rand, 1, a - 1);
      terms = [int(rand, 5, 20)];
      while (terms.length < 5) terms.push(terms[terms.length - 1] + (terms.length % 2 ? a : -b));
      break;
    }
    case 'square': {
      const start = int(rand, 1, 6);
      terms = Array.from({ length: 5 }, (_, i) => (start + i) ** 2);
      break;
    }
    default: {
      terms = [int(rand, 1, 4), int(rand, 2, 6)];
      while (terms.length < 5) terms.push(terms[terms.length - 1] + terms[terms.length - 2]);
    }
  }
  const answer = terms.pop()!;
  return { kind: 'seq', prompt: `${terms.join(', ')}, ?`, options: options(answer, rand), answer };
}

function arithmetic(level: number, rand: Rand): Question {
  const a = int(rand, 2, 6 + level * 2);
  const b = int(rand, 2, 9);
  const c = int(rand, 1, 20 + level * 3);
  const form = level < 2 ? pick(rand, ['add', 'mul']) : pick(rand, ['add', 'mul', 'mulsub', 'muladd']);
  const [prompt, answer] =
    form === 'add' ? [`${a + c} + ${c}`, a + 2 * c]
    : form === 'mul' ? [`${a} × ${b}`, a * b]
    : form === 'mulsub' ? [`${a} × ${b} − ${Math.min(c, a * b)}`, a * b - Math.min(c, a * b)]
    : [`${a} × ${b} + ${c}`, a * b + c];
  return { kind: 'math', prompt: `${prompt} = ?`, options: options(answer, rand), answer };
}

function missing(level: number, rand: Rand): Question {
  const x = int(rand, 3, 15 + level * 3);
  const b = int(rand, 2, 9);
  const mul = level >= 3 && rand() < 0.5;
  const prompt = mul ? `? × ${b} = ${x * b}` : `? + ${b + level * 3} = ${x + b + level * 3}`;
  return { kind: 'missing', prompt, options: options(x, rand), answer: x };
}

function oddOne(level: number, rand: Rand): Question {
  const k = pick(rand, level < 4 ? [2, 5, 10] : [3, 4, 6, 7, 9]);
  const fits = new Set<number>();
  while (fits.size < 3) fits.add(k * int(rand, 2, 12 + level));
  let odd = k * int(rand, 2, 12 + level) + int(rand, 1, k - 1);
  if (k === 2 && odd % 2 === 0) odd += 1;
  // Javob tugmaning o'zi: variantlar = shu to'rt son.
  return { kind: 'odd', prompt: '', options: shuffle([...fits, odd], rand), answer: odd };
}

export function question(level: number, rand: Rand = Math.random): Question {
  const make = pick(rand, [sequence, sequence, arithmetic, missing, oddOne]);
  return make(level, rand);
}

/** Daraja: har 3 ta to'g'ri javobda bittaga oshadi. */
export const levelFor = (correct: number) => Math.min(10, Math.floor(correct / 3));

/** Ochko: 10 × kombo (ketma-ket to'g'ri javoblar, eng ko'pi 5). */
export const pointsFor = (combo: number) => 10 * Math.min(5, Math.max(1, combo));

export function rankFor(score: number): 1 | 2 | 3 | 4 {
  return score < 80 ? 1 : score < 200 ? 2 : score < 400 ? 3 : 4;
}
