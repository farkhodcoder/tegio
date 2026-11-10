<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import SubHeader from '#lib/components/SubHeader.svelte';
  import { fmt } from '#lib/i18n.ts';
  import { levelFor, pointsFor, question, rankFor, type Question } from '#lib/brain.ts';
  import type { ActivePage } from '#lib/types.ts';

  let { data } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);

  const ROUND = 60_000;
  const PENALTY = 3_000;
  const BEST_KEY = 'tegio-brain-best';

  let phase = $state<'intro' | 'play' | 'over'>('intro');
  let q = $state<Question | null>(null);
  let left = $state(ROUND);
  let score = $state(0);
  let correct = $state(0);
  let combo = $state(0);
  let best = $state(0);
  let newBest = $state(false);
  let picked = $state<number | null>(null);
  let gain = $state<{ id: number; text: string } | null>(null);

  let deadline = 0;
  let timer: ReturnType<typeof setInterval> | undefined;
  let gainId = 0;

  const prompts = $derived<Record<string, string>>({ seq: m.game_seq, math: m.game_math, odd: m.game_odd, missing: m.game_missing });
  const ranks = $derived([m.rank_1, m.rank_2, m.rank_3, m.rank_4]);
  const seconds = $derived(Math.ceil(left / 1000));

  onMount(() => {
    try {
      best = Number(localStorage.getItem(BEST_KEY)) || 0;
    } catch {
      best = 0;
    }
  });
  onDestroy(() => clearInterval(timer));

  function start() {
    score = 0;
    correct = 0;
    combo = 0;
    newBest = false;
    picked = null;
    q = question(0);
    deadline = Date.now() + ROUND;
    left = ROUND;
    phase = 'play';
    clearInterval(timer);
    timer = setInterval(() => {
      left = Math.max(0, deadline - Date.now());
      if (left === 0) finish();
    }, 100);
  }

  function finish() {
    clearInterval(timer);
    phase = 'over';
    if (score > best) {
      best = score;
      newBest = true;
      try {
        localStorage.setItem(BEST_KEY, String(score));
      } catch {
        // Rekord saqlanmasa ham o'yin davom etadi.
      }
    }
  }

  function answer(value: number) {
    if (!q || picked !== null || phase !== 'play') return;
    picked = value;
    if (value === q.answer) {
      combo += 1;
      correct += 1;
      const points = pointsFor(combo);
      score += points;
      gain = { id: ++gainId, text: `+${points}` };
    } else {
      combo = 0;
      deadline -= PENALTY;
      gain = { id: ++gainId, text: '−3s' };
    }
    setTimeout(() => {
      if (phase !== 'play') return;
      picked = null;
      q = question(levelFor(correct));
    }, 380);
  }
</script>

<svelte:head><title>{m.btn_game} · {cafe.name}</title></svelte:head>

<SubHeader title={m.btn_game} />

<main class="page stack">
  {#if phase === 'intro'}
    <section class="hero panel">
      <div class="brain" aria-hidden="true">
        <svg viewBox="0 0 64 64" width="88" height="88"><circle cx="32" cy="32" r="30" fill="var(--t-game)" /><path d="M24 18a8 8 0 0 0-8 8 7 7 0 0 0 1 12 8 8 0 0 0 11 8V18Zm16 0a8 8 0 0 1 8 8 7 7 0 0 1-1 12 8 8 0 0 1-11 8V18Z" fill="var(--i-game)" /><path d="M32 18v28" stroke="#fff" stroke-width="2.5" /></svg>
      </div>
      <h2>{m.btn_game}</h2>
      <p class="muted">{m.game_sub}</p>
      {#if best}<p class="best">{m.game_best}: <b>{best}</b></p>{/if}
      <button class="btn wide" type="button" onclick={start}>{m.game_start}</button>
    </section>
  {:else if phase === 'play' && q}
    <div class="hud">
      <span class="chip score">{m.game_score}: <b>{score}</b></span>
      {#if combo >= 2}<span class="chip combo">{fmt(m.game_combo, { n: Math.min(5, combo) })}</span>{/if}
      <span class="chip time" class:low={seconds <= 10}>{seconds}s</span>
    </div>
    <div class="bar" aria-hidden="true"><span style={`width:${(left / ROUND) * 100}%`}></span></div>

    <section class="card panel">
      {#key gain?.id}{#if gain}<span class="gain" class:minus={gain.text.startsWith('−')}>{gain.text}</span>{/if}{/key}
      <p class="kind">{prompts[q.kind]}</p>
      {#if q.prompt}<p class="prompt">{q.prompt}</p>{/if}
      <div class="options">
        {#each q.options as option (option)}
          <button
            type="button"
            class:right={picked !== null && option === q.answer}
            class:wrong={picked === option && option !== q.answer}
            disabled={picked !== null}
            onclick={() => answer(option)}
          >{option}</button>
        {/each}
      </div>
    </section>
  {:else if phase === 'over'}
    <section class="hero panel" role="status">
      <h2>{m.game_over}</h2>
      <p class="big">{score}</p>
      {#if newBest}<p class="new">{m.game_new_best}</p>{/if}
      <p>{fmt(m.game_result, { n: correct })}</p>
      <p class="rank">{fmt(m.game_rank, { rank: ranks[rankFor(score) - 1] })}</p>
      <p class="best">{m.game_best}: <b>{best}</b></p>
      <button class="btn wide" type="button" onclick={start}>{m.game_again}</button>
    </section>
  {/if}
</main>

<style>
  .hero {
    display: grid;
    justify-items: center;
    gap: 6px;
    text-align: center;
  }
  .hero p {
    margin: 0;
  }
  h2 {
    margin: 4px 0 0;
    font: 600 1.5rem/1.2 var(--display);
  }
  .brain svg {
    animation: wobble 2.4s ease-in-out infinite;
  }
  .best {
    color: var(--muted);
  }
  .wide {
    width: 100%;
    margin-top: 10px;
  }
  .big {
    color: var(--primary);
    font: 700 3.5rem/1 var(--display);
    animation: pop 500ms cubic-bezier(0.3, 1.6, 0.5, 1);
  }
  .new {
    padding: 4px 14px;
    border-radius: 999px;
    background: var(--t-google);
    color: var(--i-google);
    font-weight: 700;
  }
  .rank {
    font-weight: 700;
    color: var(--i-feedback);
  }
  .hud {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
  }
  .chip {
    padding: 6px 14px;
    border-radius: 999px;
    background: var(--surface);
    box-shadow: var(--shadow);
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }
  .combo {
    background: var(--t-loyalty);
    color: var(--i-loyalty);
    animation: pop 300ms cubic-bezier(0.3, 1.6, 0.5, 1);
  }
  .time {
    margin-left: auto;
    background: var(--t-game);
    color: var(--i-game);
    font-family: var(--display);
  }
  .time.low {
    background: #ffe1e1;
    color: var(--danger);
  }
  .bar {
    height: 8px;
    overflow: hidden;
    border-radius: 999px;
    background: var(--peach);
  }
  .bar span {
    display: block;
    height: 100%;
    border-radius: inherit;
    background: linear-gradient(90deg, var(--primary), var(--sun));
    transition: width 100ms linear;
  }
  .card {
    position: relative;
    text-align: center;
  }
  .kind {
    margin: 0;
    color: var(--muted);
    font-weight: 600;
  }
  .prompt {
    margin: 10px 0 4px;
    font: 600 clamp(1.5rem, 7vw, 2.125rem)/1.2 var(--display);
    overflow-wrap: anywhere;
  }
  .options {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 10px;
    margin-top: 16px;
  }
  .options button {
    min-height: 64px;
    border: 1.5px solid var(--line);
    border-radius: 18px;
    background: var(--paper);
    color: var(--ink);
    font: 600 1.5rem var(--display);
    cursor: pointer;
    transition: transform 140ms cubic-bezier(0.3, 1.5, 0.5, 1);
  }
  .options button:active {
    transform: scale(0.95);
  }
  .options button:disabled {
    cursor: default;
  }
  .options button.right {
    border-color: var(--success);
    background: #dcf5e6;
    color: var(--success);
    transform: scale(1.04);
  }
  .options button.wrong {
    border-color: var(--danger);
    background: #ffe1e1;
    color: var(--danger);
    animation: shake 300ms;
  }
  .gain {
    position: absolute;
    top: 10px;
    right: 14px;
    color: var(--success);
    font: 700 1.25rem var(--display);
    animation: float-up 700ms ease-out forwards;
    pointer-events: none;
  }
  .gain.minus {
    color: var(--danger);
  }
  @keyframes pop {
    from {
      transform: scale(0.6);
      opacity: 0;
    }
  }
  @keyframes shake {
    25% { transform: translateX(-6px); }
    75% { transform: translateX(6px); }
  }
  @keyframes float-up {
    to {
      transform: translateY(-24px);
      opacity: 0;
    }
  }
  @keyframes wobble {
    50% {
      transform: rotate(6deg) scale(1.05);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .brain svg,
    .big,
    .combo,
    .gain,
    .options button {
      animation: none;
      transition: none;
    }
  }
</style>
