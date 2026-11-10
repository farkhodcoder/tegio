<script lang="ts">
  import { enhance } from '$app/forms';
  import LangSwitch from '#lib/components/LangSwitch.svelte';
  import Non from '#lib/components/Non.svelte';
  import OtpForm from '#lib/components/OtpForm.svelte';
  import { LOCALES, LOCALE_LABELS } from '#lib/i18n.ts';
  import { maskPhone } from '#lib/phone.ts';

  let { data, form } = $props();
  const m = $derived(data.m);
  const dateFormat = $derived(new Intl.DateTimeFormat(data.locale, { dateStyle: 'medium', timeStyle: 'short' }));
  let confirmingDelete = $state(false);

  const total = (tiers: { stamps_required: number }[]) => Math.max(1, ...tiers.map((t) => t.stamps_required));
</script>

<svelte:head><title>{m.me_title} · TEGIO</title></svelte:head>

<header class="bar">
  <h1>{m.me_title}</h1>
  <LangSwitch />
</header>

<main class="page stack">
  {#if !data.profile}
    <p>{m.me_login}</p>
    <OtpForm result={form} />
  {:else}
    {#if data.cards.length}
      {#each data.cards as card (card.membership_id)}
        <article class="panel card">
          <div class="mini"><Non stamps={card.stamps} total={total(card.tiers)} tiers={card.tiers.map((t) => t.stamps_required)} /></div>
          <div class="body">
            <h2>{card.business_name}</h2>
            <p>{card.stamps} / {total(card.tiers)} {m.card_stamps}</p>
            {#each card.rewards as reward (reward.id)}
              <p class="reward">{reward.title}</p>
            {/each}
            <a href={`/${card.slug}/karta`}>{m.me_open}</a>
          </div>
          <form method="POST" action="?/marketing" use:enhance class="foot">
            <input type="hidden" name="membership_id" value={card.membership_id} />
            <label class="check">
              <input type="checkbox" name="consent" checked={card.marketing_consent} onchange={(e) => e.currentTarget.form?.requestSubmit()} />
              <span>{m.me_marketing}</span>
            </label>
          </form>
          <form method="POST" action="?/leave" use:enhance class="foot">
            <input type="hidden" name="membership_id" value={card.membership_id} />
            <button class="link">{m.me_leave}</button>
          </form>
        </article>
      {/each}
    {:else}
      <p class="muted">{m.me_cards_empty}</p>
    {/if}

    <section>
      <h2>{m.me_visits}</h2>
      {#if data.visits.length}
        <ul>
          {#each data.visits as visit, index (index)}
            <li>
              <span>{visit.business_name} · {visit.kind === 'stamp' ? m.me_visit_stamp : m.me_visit_redeem}</span>
              <time class="muted" datetime={visit.at}>{dateFormat.format(new Date(visit.at))}</time>
            </li>
          {/each}
        </ul>
      {:else}
        <p class="muted">{m.me_visits_empty}</p>
      {/if}
    </section>

    <section class="stack">
      <h2>{m.me_profile}</h2>
      <p class="muted">{maskPhone(data.profile.phone)}</p>
      <form method="POST" action="?/profile" use:enhance={() => ({ update }) => update({ reset: false, invalidateAll: true })} class="stack">
        <label>{m.field_name}<input name="name" value={data.profile.name} maxlength="80" /></label>
        <label>
          {m.me_language}
          <select name="locale" value={data.locale}>
            {#each LOCALES as locale (locale)}<option value={locale}>{LOCALE_LABELS[locale]}</option>{/each}
          </select>
        </label>
        {#if form?.saved}<p class="ok" role="status">{m.me_saved}</p>{/if}
        <button class="btn">{m.me_save}</button>
      </form>
      <form method="POST" action="?/logout"><button class="btn ghost wide">{m.me_logout}</button></form>
    </section>

    <section class="stack">
      <h2>{m.me_delete_title}</h2>
      <p class="muted">{m.me_delete_sub}</p>
      {#if confirmingDelete}
        <form method="POST" action="?/delete"><button class="btn danger wide">{m.me_delete}</button></form>
      {:else}
        <button class="btn ghost wide" onclick={() => (confirmingDelete = true)}>{m.me_delete}</button>
      {/if}
    </section>
  {/if}
</main>

<style>
  .bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 10px 10px 18px;
    border-radius: 0 0 24px 24px;
    background: var(--primary);
    color: var(--on-primary);
  }
  h1 {
    margin: 0;
    font: 500 1.25rem var(--display);
  }
  h2 {
    margin: 0 0 8px;
    font: 500 1.0625rem/1.3 var(--display);
  }
  .card {
    display: grid;
    grid-template-columns: 96px minmax(0, 1fr);
    gap: 12px;
  }
  .body p {
    margin: 0;
  }
  .reward {
    color: var(--accent);
    font-weight: 700;
  }
  .foot {
    grid-column: 1 / -1;
  }
  .link {
    padding: 8px 0;
    border: 0;
    background: none;
    color: var(--danger);
    font: inherit;
    cursor: pointer;
    text-decoration: underline;
  }
  .wide {
    width: 100%;
  }
  ul {
    margin: 0;
    padding: 0;
    list-style: none;
  }
  li {
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    gap: 2px 12px;
    padding: 10px 0;
    border-bottom: 1px solid var(--line);
  }
  time {
    font-size: 0.875rem;
  }
</style>
