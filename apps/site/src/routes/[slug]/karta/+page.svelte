<script lang="ts">
  import { enhance } from '$app/forms';
  import Non from '#lib/components/Non.svelte';
  import OtpForm from '#lib/components/OtpForm.svelte';
  import SubHeader from '#lib/components/SubHeader.svelte';
  import { fmt } from '#lib/i18n.ts';
  import type { ActivePage, CardState } from '#lib/types.ts';

  const POLL_MS = 4000;

  let { data, form } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);
  const tiers = $derived(cafe.program?.tiers ?? []);
  const total = $derived(Math.max(1, ...tiers.map((t) => t.stamps_required)));
  const tierStops = $derived(tiers.map((t) => t.stamps_required));

  let live = $state<CardState | null>(null);
  let qr = $state('');
  let expiresAt = $state(0);
  let secondsLeft = $state(60);
  let freshIndex = $state(-1);
  let latestRequest = 0;

  const card = $derived(live ?? data.card);
  const next = $derived(tiers.find((t) => t.stamps_required > (card?.stamps ?? 0)));
  const hasCard = $derived(!!data.card);

  async function refresh(withQr: boolean) {
    const request = ++latestRequest;
    const res = await fetch(`/api/card?slug=${cafe.slug}${withQr ? '&qr=1' : ''}`).catch(() => null);
    if (!res?.ok) return;
    const body = await res.json();
    // Kechikkan javob yangi holatni eskisi bilan almashtirmasligi kerak.
    if (request === latestRequest) {
      if (body.card.stamps > (card?.stamps ?? 0)) freshIndex = body.card.stamps - 1;
      live = body.card;
    }
    if (body.qr && body.expiresAt >= expiresAt) {
      qr = body.qr;
      expiresAt = body.expiresAt;
    }
  }

  // Kod 60 soniyada yangilanadi, shtamp sahifani yangilamasdan ko'rinadi (L-04, L-05).
  $effect(() => {
    if (!hasCard) return;
    refresh(true);
    const poll = setInterval(() => {
      if (!document.hidden) refresh(false);
    }, POLL_MS);
    const tick = setInterval(() => {
      secondsLeft = Math.max(0, expiresAt - Math.floor(Date.now() / 1000));
      if (expiresAt && secondsLeft <= 2 && !document.hidden) refresh(true);
    }, 1000);
    return () => {
      clearInterval(poll);
      clearInterval(tick);
    };
  });
</script>

<svelte:head><title>{m.card_title} · {cafe.name}</title></svelte:head>

<SubHeader title={m.card_title} />

<main class="page stack">
  {#if !cafe.program}
    <p class="muted">{m.card_unavailable}</p>
  {:else if card}
    <div class="disc">
      <Non stamps={card.stamps} {total} tiers={tierStops} unit={m.card_stamps} {freshIndex} />
    </div>
    {#if next}
      <p class="next">{fmt(m.card_next, { title: next.title, n: next.stamps_required - card.stamps })}</p>
    {/if}

    <section class="panel qr">
      <h2>{m.card_show}</h2>
      <div class="code">
        {#if qr}{@html qr}{/if}
      </div>
      <p class="muted" aria-live="off">{fmt(m.card_refresh, { n: secondsLeft })}</p>
    </section>

    {#if data.demo}
      <form method="POST" action="?/demoStamp" use:enhance={() => async () => refresh(false)}>
        <button class="btn ghost wide">{m.card_demo_stamp}</button>
      </form>
    {/if}

    <section>
      <h2>{m.card_rewards}</h2>
      {#if card.rewards.length}
        <ul>
          {#each card.rewards as reward (reward.id)}
            <li class="panel">{reward.title}</li>
          {/each}
        </ul>
      {:else}
        <p class="muted">{fmt(m.card_no_rewards, { n: tiers[0]?.stamps_required ?? 0 })}</p>
      {/if}
    </section>
  {:else if data.signedIn}
    <div class="preview"><Non stamps={0} {total} tiers={tierStops} /></div>
    <form method="POST" action="?/join" use:enhance class="stack">
      <label>{m.field_name}<input name="name" autocomplete="given-name" maxlength="80" /></label>
      <label class="check"><input type="checkbox" name="terms" required /><span>{m.card_terms} (<a href="/shartlar" target="_blank">{m.terms}</a>)</span></label>
      <label class="check"><input type="checkbox" name="marketing" /><span>{m.card_marketing}</span></label>
      {#if form?.joinError === 'terms'}<p class="error" role="alert">{m.card_need_terms}</p>{/if}
      <button class="btn">{m.card_join}</button>
    </form>
  {:else}
    <div class="preview"><Non stamps={0} {total} tiers={tierStops} /></div>
    <p>{m.card_intro}</p>
    <OtpForm result={form} />
  {/if}
</main>

<style>
  .disc {
    width: min(100%, 320px);
    margin-inline: auto;
  }
  .preview {
    width: 180px;
    margin-inline: auto;
  }
  .next {
    margin: 0;
    font-weight: 700;
    text-align: center;
  }
  h2 {
    margin: 0 0 8px;
    font: 500 1.0625rem/1.3 var(--display);
  }
  .qr {
    text-align: center;
  }
  .code {
    width: min(100%, 240px);
    aspect-ratio: 1;
    margin-inline: auto;
  }
  .code :global(svg) {
    display: block;
    width: 100%;
    height: 100%;
  }
  .qr p {
    margin: 8px 0 0;
    font-size: 0.875rem;
  }
  .wide {
    width: 100%;
  }
  ul {
    display: grid;
    gap: 8px;
    margin: 0;
    padding: 0;
    list-style: none;
  }
  li {
    font-weight: 700;
  }
</style>
