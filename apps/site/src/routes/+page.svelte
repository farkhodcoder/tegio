<script lang="ts">
  import { enhance } from '$app/forms';
  import { page } from '$app/state';
  import LangSwitch from '#lib/components/LangSwitch.svelte';
  import Non from '#lib/components/Non.svelte';
  import { brand } from '#lib/brand.ts';
  import { formatPrice } from '#lib/menu.ts';

  let { data, form } = $props();
  const m = $derived(data.m);

  const planText = $derived<Record<string, string>>({
    free: m.plan_free,
    start: m.plan_start,
    pro: m.plan_pro,
    network: m.plan_network
  });
  const steps = $derived([m.how_1, m.how_2, m.how_3, m.how_4, m.how_5]);
  const guestFeatures = $derived([
    [m.btn_menu, m.guest_menu],
    [m.btn_wifi, m.guest_wifi],
    [m.btn_loyalty, m.guest_card],
    [m.btn_feedback, m.guest_feedback]
  ]);
</script>

<svelte:head>
  <title>{brand.name}: {m.site_tagline}</title>
  <meta name="description" content={m.hero_sub} />
  <meta property="og:title" content={`${brand.name}: ${m.site_tagline}`} />
  <meta property="og:description" content={m.hero_sub} />
  <meta property="og:type" content="website" />
  <meta property="og:url" content={page.url.origin} />
</svelte:head>

<div class="top">
  <header class="bar">
    <a class="mark" href="/">{brand.name}</a>
    <nav>
      <a href="#narxlar">{m.nav_prices}</a>
      <a href="/me">{m.nav_me}</a>
    </nav>
    <LangSwitch />
  </header>

  <section class="hero">
    <div class="copy">
      <h1>{m.hero_title}</h1>
      <p>{m.hero_sub}</p>
      <div class="actions">
        <a class="btn light" href={data.bizUrl}>{m.cta_start}</a>
        <a class="btn outline" href="/anor?t=S7">{m.cta_sample}</a>
      </div>
    </div>
    <div class="disc"><Non stamps={7} total={10} tiers={[5, 10]} animate startDeg={100} /></div>
  </section>
</div>

<section class="section features">
  <h2>{m.guest_title}</h2>
  <dl>
    {#each guestFeatures as [title, text] (title)}
      <div>
        <dt>{title}</dt>
        <dd>{text}</dd>
      </div>
    {/each}
  </dl>
</section>

<section class="section setup" id="qanday">
  <h2>{m.how_title}</h2>
  <ol>
    {#each steps as step, index (index)}
      <li><span>{index + 1}</span>{step}</li>
    {/each}
  </ol>
</section>

<section class="section" id="narxlar">
  <h2>{m.prices_title}</h2>
  <p class="muted">{m.prices_note}</p>
  <div class="plans">
    {#each data.plans as plan (plan.id)}
      <article class:featured={plan.id === 'start'}>
        <h3>{plan.name}</h3>
        <p class="price">
          {#if plan.price_uzs === null}{m.plan_custom}{:else}{formatPrice(plan.price_uzs)} <small>{m.som}</small>{/if}
        </p>
        <p>{planText[plan.id]}</p>
      </article>
    {/each}
  </div>
</section>

<section class="section demo">
  <div>
    <h2>{m.demo_title}</h2>
    <p class="muted">{m.demo_sub}</p>
  </div>
  {#if form?.demoDone}
    <p class="ok" role="status">{m.demo_done}</p>
  {:else}
    <form method="POST" action="?/demo" use:enhance class="stack">
      <label>{m.field_name}<input name="name" required autocomplete="name" /></label>
      <label>{m.field_phone}<input name="phone" type="tel" required autocomplete="tel" placeholder="90 123 45 67" aria-invalid={form?.demoError ? 'true' : undefined} /></label>
      <label>{m.field_business}<input name="business_name" autocomplete="organization" /></label>
      {#if form?.demoError}<p class="error" role="alert">{m.card_bad_phone}</p>{/if}
      <button class="btn">{m.demo_send}</button>
    </form>
  {/if}
</section>

<footer>
  <span class="mark">{brand.name}</span>
  <a href="/shartlar">{m.terms}</a>
  <a href="/maxfiylik">{m.privacy}</a>
</footer>

<style>
  .top {
    position: relative;
    overflow: hidden;
    border-radius: 0 0 40px 40px;
    background:
      radial-gradient(circle at 92% 8%, var(--sun) 0 140px, transparent 141px),
      radial-gradient(circle at 70% 115%, #ff9a5c 0 190px, transparent 191px),
      var(--primary);
    color: var(--on-primary);
  }
  .bar {
    display: flex;
    align-items: center;
    gap: 16px;
    width: min(100%, 1120px);
    margin-inline: auto;
    padding: 12px 16px;
  }
  .mark {
    font: 700 1.25rem var(--display);
    letter-spacing: 0.04em;
    color: inherit;
    text-decoration: none;
  }
  nav {
    display: flex;
    gap: 16px;
    margin-left: auto;
  }
  nav a {
    color: inherit;
    font-weight: 600;
    text-decoration: none;
  }
  .hero {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 460px);
    align-items: center;
    gap: 32px;
    width: min(100%, 1120px);
    margin-inline: auto;
    padding: 40px 16px 72px;
  }
  h1 {
    margin: 0 0 20px;
    font: 500 clamp(2rem, 5.2vw, 3.75rem)/1.08 var(--display);
  }
  .copy p {
    max-width: 34em;
    margin: 0 0 28px;
    font-size: 1.125rem;
  }
  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
  }
  .btn.light {
    background: #fff;
    color: var(--primary);
    box-shadow: 0 8px 20px rgb(80 20 0 / 25%);
  }
  .btn.outline {
    border: 1.5px solid currentColor;
    background: transparent;
    color: inherit;
  }
  .disc {
    margin-right: -40px;
    margin-bottom: -110px;
    filter: drop-shadow(0 18px 30px rgb(80 20 0 / 30%));
    animation: float 6s ease-in-out infinite;
  }
  @keyframes float {
    50% {
      transform: translateY(-10px) rotate(3deg);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .disc {
      animation: none;
    }
  }
  .section {
    width: min(100%, 1120px);
    margin-inline: auto;
    padding: 56px 16px 0;
  }
  h2 {
    margin: 0 0 20px;
    font: 500 clamp(1.375rem, 3vw, 2rem)/1.2 var(--display);
  }
  dl {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px;
    margin: 0;
  }
  dl div {
    padding: 20px;
    border-radius: var(--radius);
    background: var(--t);
  }
  dl div:nth-child(1) { --t: var(--t-menu); --i: var(--i-menu); }
  dl div:nth-child(2) { --t: var(--t-wifi); --i: var(--i-wifi); }
  dl div:nth-child(3) { --t: var(--t-loyalty); --i: var(--i-loyalty); }
  dl div:nth-child(4) { --t: var(--t-feedback); --i: var(--i-feedback); }
  dt {
    color: var(--i);
    font: 600 1.125rem var(--display);
  }
  dd {
    color: var(--ink) !important;
  }
  dd {
    margin: 4px 0 0;
    color: var(--muted);
  }
  ol {
    display: grid;
    grid-template-columns: repeat(5, minmax(0, 1fr));
    gap: 16px;
    margin: 0;
    padding: 0;
    list-style: none;
  }
  li span {
    display: grid;
    place-items: center;
    width: 52px;
    height: 52px;
    margin-bottom: 10px;
    border-radius: 18px;
    background: var(--primary);
    color: var(--on-primary);
    font: 600 1.5rem var(--display);
    transform: rotate(-6deg);
  }
  li:nth-child(even) span {
    background: var(--accent);
    transform: rotate(5deg);
  }
  .plans {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 12px;
  }
  article {
    padding: 22px;
    border: 1px solid var(--line);
    border-radius: var(--radius);
    background: var(--surface);
    box-shadow: var(--shadow);
  }
  article.featured {
    border: 0;
    background: var(--primary);
    color: var(--on-primary);
    box-shadow: var(--shadow-lift);
    transform: rotate(-1.5deg);
  }
  article.featured p:last-child {
    color: inherit;
    opacity: 0.9;
  }
  h3 {
    margin: 0;
    font: 500 1.125rem var(--display);
  }
  .price {
    margin: 12px 0;
    font-size: 1.5rem;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
  .price small {
    font-size: 0.875rem;
    font-weight: 400;
  }
  article p:last-child {
    margin: 0;
    color: var(--muted);
  }
  .demo {
    width: min(calc(100% - 32px), 1088px);
    margin-top: 56px;
    padding: 32px 24px;
    border-radius: 32px;
    background: var(--peach);
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 420px);
    gap: 32px;
  }
  footer {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 20px;
    width: min(100%, 1120px);
    margin: 64px auto 0;
    padding: 24px 16px;
    border-top: 1px solid var(--line);
  }
  @media (max-width: 820px) {
    .hero,
    .demo {
      grid-template-columns: minmax(0, 1fr);
    }
    .hero {
      padding-bottom: 0;
    }
    .disc {
      width: 300px;
      margin: 8px -60px -120px auto;
    }
    dl,
    .plans {
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }
    ol {
      grid-template-columns: minmax(0, 1fr);
    }
    li {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    li span {
      flex: none;
      width: 44px;
      height: 44px;
      margin: 0;
      font-size: 1.25rem;
    }
  }
  @media (max-width: 520px) {
    nav a:first-child {
      display: none;
    }
    dl,
    .plans {
      grid-template-columns: minmax(0, 1fr);
    }
  }
</style>
