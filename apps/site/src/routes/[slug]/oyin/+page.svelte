<script lang="ts">
  import { onMount } from 'svelte';
  import SubHeader from '#lib/components/SubHeader.svelte';
  import { fmt } from '#lib/i18n.ts';
  import { conflicts, formatTime, isSolved, peersOf, puzzle, type Board, type Level } from '#lib/sudoku.ts';
  import type { ActivePage } from '#lib/types.ts';

  let { data } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);

  const KEY = 'tegio-sudoku';
  type Saved = { level: Level; given: Board; board: Board; seconds: number };

  let level = $state<Level>('easy');
  let given = $state<Board>([]);
  let board = $state<Board>([]);
  let seconds = $state(0);
  let selected = $state(-1);

  const bad = $derived(conflicts(board));
  const solved = $derived(board.length === 81 && isSolved(board));
  const related = $derived(selected < 0 ? new Set<number>() : new Set(peersOf(selected)));
  const selectedValue = $derived(selected < 0 ? 0 : board[selected]);

  function save() {
    try {
      localStorage.setItem(KEY, JSON.stringify({ level, given, board, seconds } satisfies Saved));
    } catch {
      // Brauzer xotirasi yopiq bo'lsa o'yin baribir ishlaydi, faqat saqlanmaydi.
    }
  }

  function start(next: Level) {
    level = next;
    given = puzzle(next);
    board = [...given];
    seconds = 0;
    selected = given.indexOf(0);
    save();
  }

  onMount(() => {
    let saved: Saved | null = null;
    try {
      saved = JSON.parse(localStorage.getItem(KEY) ?? 'null');
    } catch {
      saved = null;
    }
    if (saved && saved.given?.length === 81 && saved.board?.length === 81) {
      ({ level, given, board, seconds } = saved);
      selected = board.indexOf(0);
    } else {
      start('easy');
    }
    const tick = setInterval(() => {
      if (!solved && !document.hidden) {
        seconds += 1;
        if (seconds % 5 === 0) save();
      }
    }, 1000);
    return () => clearInterval(tick);
  });

  function put(value: number) {
    if (selected < 0 || given[selected] || solved) return;
    board[selected] = value;
    save();
  }

  function onKey(event: KeyboardEvent) {
    if (/^[1-9]$/.test(event.key)) put(Number(event.key));
    else if (event.key === 'Backspace' || event.key === 'Delete' || event.key === '0') put(0);
    else {
      const move: Record<string, number> = { ArrowUp: -9, ArrowDown: 9, ArrowLeft: -1, ArrowRight: 1 };
      if (!(event.key in move)) return;
      const next = (selected < 0 ? 0 : selected) + move[event.key];
      if (next >= 0 && next < 81) selected = next;
    }
    event.preventDefault();
  }

  // Raqam taxtada 9 marta turgan bo'lsa, tugmasi xira.
  const used = $derived(Array.from({ length: 10 }, (_, d) => board.filter((v) => v === d).length));
</script>

<svelte:head><title>{m.btn_game} · {cafe.name}</title></svelte:head>

<SubHeader title={m.btn_game} />

<main class="page stack">
  <p class="muted intro">{m.game_sub}</p>

  <div class="bar">
    <div class="levels" role="group">
      {#each [['easy', m.game_easy], ['hard', m.game_hard]] as [id, text] (id)}
        <button type="button" aria-pressed={level === id} onclick={() => start(id as Level)}>{text}</button>
      {/each}
    </div>
    <span class="time" aria-live="off">{formatTime(seconds)}</span>
  </div>

  {#if board.length === 81}
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <div class="grid" class:done={solved} role="grid" tabindex="-1" onkeydown={onKey}>
      {#each board as value, index (index)}
        <button
          type="button"
          role="gridcell"
          class:given={given[index] !== 0}
          class:sel={index === selected}
          class:rel={related.has(index)}
          class:same={selectedValue !== 0 && value === selectedValue}
          class:bad={bad.has(index)}
          class:right={index % 9 === 2 || index % 9 === 5}
          class:bottom={Math.floor(index / 9) === 2 || Math.floor(index / 9) === 5}
          aria-label={`${fmt(m.game_cell, { r: Math.floor(index / 9) + 1, c: (index % 9) + 1 })}${value ? `: ${value}` : ''}`}
          aria-selected={index === selected}
          onclick={() => (selected = index)}
        >{value || ''}</button>
      {/each}
    </div>

    {#if solved}
      <p class="win" role="status">{fmt(m.game_solved, { time: formatTime(seconds) })}</p>
      <button class="btn" type="button" onclick={() => start(level)}>{m.game_new}</button>
    {:else}
      <div class="pad">
        {#each [1, 2, 3, 4, 5, 6, 7, 8, 9] as digit (digit)}
          <button type="button" class:full={used[digit] >= 9} onclick={() => put(digit)}>{digit}</button>
        {/each}
        <button type="button" class="erase" onclick={() => put(0)}>{m.game_erase}</button>
      </div>
      <button class="btn ghost" type="button" onclick={() => start(level)}>{m.game_new}</button>
    {/if}
  {/if}
</main>

<style>
  .intro {
    margin: 0;
  }
  .bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
  }
  .levels {
    display: flex;
    gap: 4px;
    padding: 4px;
    border-radius: 999px;
    background: var(--peach);
  }
  .levels button {
    min-height: 40px;
    padding: 6px 16px;
    border: 0;
    border-radius: 999px;
    background: transparent;
    color: var(--ink);
    font: inherit;
    font-weight: 600;
    cursor: pointer;
  }
  .levels button[aria-pressed='true'] {
    background: var(--surface);
    box-shadow: var(--shadow);
    font-weight: 700;
  }
  .time {
    padding: 6px 14px;
    border-radius: 999px;
    background: var(--t-game);
    color: var(--i-game);
    font: 600 1rem var(--display);
    font-variant-numeric: tabular-nums;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(9, minmax(0, 1fr));
    overflow: hidden;
    border: 3px solid var(--ink);
    border-radius: 18px;
    background: var(--surface);
    box-shadow: var(--shadow-lift);
  }
  .grid.done {
    border-color: var(--success);
    animation: cheer 600ms cubic-bezier(0.3, 1.6, 0.5, 1);
  }
  .grid button {
    aspect-ratio: 1;
    min-width: 0;
    padding: 0;
    border: 0;
    border-right: 1px solid var(--line);
    border-bottom: 1px solid var(--line);
    background: transparent;
    color: var(--i-game);
    font: 600 clamp(1rem, 5vw, 1.375rem) var(--display);
    cursor: pointer;
  }
  .grid button.right {
    border-right: 2px solid var(--ink);
  }
  .grid button.bottom {
    border-bottom: 2px solid var(--ink);
  }
  .grid button:nth-child(9n) {
    border-right: 0;
  }
  .grid button:nth-child(n + 73) {
    border-bottom: 0;
  }
  .grid button.given {
    color: var(--ink);
  }
  .grid button.rel {
    background: #fff4ec;
  }
  .grid button.same {
    background: var(--peach);
  }
  .grid button.sel {
    background: var(--dough);
  }
  .grid button.bad {
    background: #ffe1e1;
    color: var(--danger);
  }
  .grid button:focus-visible {
    outline-offset: -3px;
  }
  .pad {
    display: grid;
    grid-template-columns: repeat(5, minmax(0, 1fr));
    gap: 8px;
  }
  .pad button {
    min-height: 52px;
    border: 1px solid var(--line);
    border-radius: 16px;
    background: var(--surface);
    box-shadow: var(--shadow);
    color: var(--ink);
    font: 600 1.25rem var(--display);
    cursor: pointer;
    transition: transform 140ms cubic-bezier(0.3, 1.5, 0.5, 1);
  }
  .pad button:active {
    transform: scale(0.92);
  }
  .pad button.full {
    opacity: 0.35;
  }
  .pad .erase {
    font: 700 0.875rem var(--body);
  }
  .win {
    margin: 0;
    padding: 14px 16px;
    border-radius: 18px;
    background: #dcf5e6;
    color: var(--success);
    font-weight: 700;
    text-align: center;
  }
  @keyframes cheer {
    40% {
      transform: scale(1.03) rotate(-1deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .grid.done,
    .pad button {
      animation: none;
      transition: none;
    }
  }
</style>
