// Kutish paytidagi mini-o'yin. Board: 81 ta katak, 0 = bo'sh.
export type Board = number[];
export type Level = 'easy' | 'hard';

// Bo'sh qoldiriladigan kataklar soni.
const HOLES: Record<Level, number> = { easy: 38, hard: 50 };

function shuffle<T>(items: T[], rand: () => number): T[] {
  const list = [...items];
  for (let i = list.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [list[i], list[j]] = [list[j], list[i]];
  }
  return list;
}

// Har guruh ichida (polosa yoki ustunlar to'plami) aralashtirilgan 0..8 tartib.
function groupedOrder(rand: () => number): number[] {
  return shuffle([0, 1, 2], rand).flatMap((band) => shuffle([0, 1, 2], rand).map((i) => band * 3 + i));
}

/** To'liq to'g'ri yechim: tayyor naqshdan raqam, qator va ustunlarni aralashtirib olinadi. */
export function solution(rand: () => number = Math.random): Board {
  const digits = shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9], rand);
  const rows = groupedOrder(rand);
  const cols = groupedOrder(rand);
  const flip = rand() < 0.5;
  const board: Board = [];
  for (let r = 0; r < 9; r++) {
    for (let c = 0; c < 9; c++) {
      const [rr, cc] = flip ? [cols[c], rows[r]] : [rows[r], cols[c]];
      board.push(digits[(rr * 3 + Math.floor(rr / 3) + cc) % 9]);
    }
  }
  return board;
}

export function puzzle(level: Level, rand: () => number = Math.random): Board {
  const board = solution(rand);
  for (const index of shuffle([...board.keys()], rand).slice(0, HOLES[level])) board[index] = 0;
  return board;
}

function peers(index: number): number[] {
  const r = Math.floor(index / 9);
  const c = index % 9;
  const br = r - (r % 3);
  const bc = c - (c % 3);
  const list = new Set<number>();
  for (let i = 0; i < 9; i++) {
    list.add(r * 9 + i);
    list.add(i * 9 + c);
    list.add((br + Math.floor(i / 3)) * 9 + bc + (i % 3));
  }
  list.delete(index);
  return [...list];
}

const PEERS = Array.from({ length: 81 }, (_, i) => peers(i));

export function peersOf(index: number): number[] {
  return PEERS[index];
}

/** Qoidaga zid kataklar: qator, ustun yoki 3×3 katakda takrorlangan raqam. */
export function conflicts(board: Board): Set<number> {
  const bad = new Set<number>();
  board.forEach((value, index) => {
    if (value && PEERS[index].some((p) => board[p] === value)) bad.add(index);
  });
  return bad;
}

/** Yechim yagona bo'lishi shart emas: qoidaga mos to'la taxta yechilgan hisoblanadi. */
export function isSolved(board: Board): boolean {
  return board.length === 81 && board.every((v) => v >= 1 && v <= 9) && conflicts(board).size === 0;
}

export function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}
