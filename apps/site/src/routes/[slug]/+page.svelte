<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import LangSwitch from '#lib/components/LangSwitch.svelte';
  import RowIcon from '#lib/components/RowIcon.svelte';
  import { fmt } from '#lib/i18n.ts';
  import { safeHttpUrl } from '#lib/links.ts';
  import type { ActivePage, LandingItem } from '#lib/types.ts';

  let { data } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);
  const tagCode = $derived(page.url.searchParams.get('t'));

  const INTERNAL: Record<string, string> = { menu: 'menu', wifi: 'wifi', loyalty: 'karta', feedback: 'fikr' };

  function track(action: string) {
    const body = JSON.stringify({ slug: cafe.slug, action, tag: tagCode });
    navigator.sendBeacon('/api/event', new Blob([body], { type: 'application/json' }));
  }

  onMount(() => track('scan'));

  function href(item: LandingItem): string {
    const sub = INTERNAL[item.kind];
    return sub ? `/${cafe.slug}/${sub}${page.url.search}` : (safeHttpUrl(item.url) ?? '#');
  }

  function label(item: LandingItem): string {
    if (item.label) return item.label;
    const all = m as Record<string, string>;
    return all[`row_${item.kind}`] ?? all[`btn_${item.kind}`] ?? item.kind;
  }

  const internal = $derived(cafe.items.filter((i) => INTERNAL[i.kind]));
  const external = $derived(cafe.items.filter((i) => !INTERNAL[i.kind]));
  const initials = $derived(cafe.name.slice(0, 1).toLocaleUpperCase());

  type Row = { kind: string; href: string; text: string; external: boolean };

  // Tartib namunadagidek: avval bonus, keyin sharh, menyu, Wi-Fi, taklif qutisi va o'yin.
  const ORDER = ['loyalty', 'google', 'menu', 'wifi', 'feedback', 'game'];

  const rows = $derived.by(() => {
    const list: Row[] = internal.map((item) => ({ kind: item.kind, href: href(item), text: label(item), external: false }));
    // F-03, F-04: qator bahoga bog'liq emas va hech qanday mukofot bermaydi.
    const google = safeHttpUrl(cafe.location.google_review_url);
    if (google) list.push({ kind: 'google', href: google, text: m.fb_google_title, external: true });
    // Kutish paytidagi aql o'yini: hamma kafeda.
    list.push({ kind: 'game', href: `/${cafe.slug}/oyin${page.url.search}`, text: m.row_game, external: false });
    return list.sort((a, b) => ORDER.indexOf(a.kind) - ORDER.indexOf(b.kind));
  });
</script>

<svelte:head>
  <title>{cafe.name}</title>
  <meta name="description" content={cafe.brand.tagline ?? cafe.name} />
</svelte:head>

<header class="cover" class:photo={!!cafe.brand.cover_url} style={cafe.brand.cover_url ? `background-image:url(${JSON.stringify(cafe.brand.cover_url)})` : undefined}>
  <div class="tools"><LangSwitch /></div>
  {#if !cafe.brand.cover_url}
    <svg class="ikat" aria-hidden="true" preserveAspectRatio="xMidYMid slice" viewBox="0 0 400 160">
      <defs>
        <pattern id="ikat" width="80" height="80" patternUnits="userSpaceOnUse">
          <path d="M40 2 L72 40 L40 78 L8 40 Z" fill="none" stroke="currentColor" stroke-width="7" />
          <path d="M40 24 L55 40 L40 56 L25 40 Z" fill="currentColor" />
          <path d="M0 0 L8 10 L0 20 Z M80 60 L72 70 L80 80 Z" fill="currentColor" />
        </pattern>
      </defs>
      <rect width="400" height="160" fill="url(#ikat)" />
    </svg>
  {/if}
</header>

<main class="page">
  <div class="head">
    <div class="logo">
      {#if cafe.brand.logo_url}
        <img src={cafe.brand.logo_url} alt="" width="96" height="96" />
      {:else}
        <span aria-hidden="true">{initials}</span>
      {/if}
    </div>
    <div class="title">
      <h1>{cafe.name}</h1>
      {#if cafe.brand.tagline}<p class="tagline">{cafe.brand.tagline}</p>{/if}
    </div>
  </div>
  <p class="where">
    {cafe.location.name}{#if cafe.tag?.table_label}{' · '}{fmt(m.table, { n: cafe.tag.table_label })}{/if}
  </p>

  <nav class="rows">
    {#each rows as row (row.kind)}
      <a href={row.href} target={row.external ? '_blank' : undefined} rel={row.external ? 'noopener' : undefined} onclick={() => track(row.kind)}>
        <span class="icon" style={`--t:var(--t-${row.kind})`}><RowIcon kind={row.kind} /></span>
        <span class="text">{row.text}</span>
        <svg class="go" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path d={row.external ? 'M8 16L16 8M9 8h7v7' : 'M9 5l7 7-7 7'} fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" /></svg>
      </a>
    {/each}
  </nav>

  {#if external.length}
    <nav class="links">
      {#each external as item (item.kind + item.url)}
        <a href={href(item)} target="_blank" rel="noopener" onclick={() => track(item.kind)}>{label(item)}</a>
      {/each}
    </nav>
  {/if}

  {#if cafe.show_branding}
    <a class="powered" href="/">{m.powered}</a>
  {/if}
</main>

<style>
  .cover {
    position: relative;
    height: 220px;
    overflow: hidden;
    border-radius: 0 0 32px 32px;
    background: var(--biz) center / cover;
    color: var(--on-biz);
  }
  .cover::before,
  .cover::after {
    content: '';
    position: absolute;
    border-radius: 50%;
    background: currentColor;
    opacity: 0.12;
  }
  .cover.photo::before,
  .cover.photo::after {
    display: none;
  }
  .cover::before {
    width: 220px;
    height: 220px;
    top: -90px;
    left: -60px;
  }
  .cover::after {
    width: 160px;
    height: 160px;
    right: -40px;
    bottom: -70px;
  }
  .ikat {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    opacity: 0.16;
  }
  .tools {
    position: absolute;
    z-index: 1;
    top: 10px;
    right: 10px;
    border-radius: 12px;
    background: color-mix(in srgb, #000 14%, transparent);
    backdrop-filter: blur(6px);
  }
  .head {
    display: flex;
    align-items: flex-start;
    gap: 14px;
    margin-top: -52px;
  }
  /* Nom muqova ustiga chiqmasin: logotipning pastki yarmi yonidan boshlanadi. */
  .title {
    flex: 1;
    min-width: 0;
    padding-top: 60px;
  }
  .logo {
    flex: none;
    display: grid;
    place-items: center;
    width: 96px;
    height: 96px;
    position: relative;
    overflow: hidden;
    border: 5px solid var(--surface);
    border-radius: 50%;
    background: var(--dough);
    box-shadow: var(--shadow-lift);
    color: #4a2d05;
    font: 600 2.25rem var(--display);
    animation: pop 520ms cubic-bezier(0.3, 1.5, 0.5, 1) backwards;
  }
  .logo img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  h1 {
    margin: 0 0 2px;
    font: 600 clamp(1.375rem, 6vw, 1.75rem)/1.15 var(--display);
    overflow-wrap: anywhere;
  }
  .tagline {
    margin: 0;
    color: var(--muted);
    font-size: 0.9375rem;
  }
  .where {
    display: inline-flex;
    margin: 10px 0 0;
    padding: 4px 12px;
    border-radius: 999px;
    background: var(--peach);
    color: #7a2a0a;
    font-size: 0.875rem;
    font-weight: 600;
  }
  .rows {
    display: grid;
    gap: 10px;
    margin-top: 22px;
  }
  .rows a {
    display: flex;
    align-items: center;
    gap: 14px;
    min-height: 72px;
    padding: 12px 14px;
    border: 1px solid var(--line);
    border-radius: var(--radius);
    background: var(--surface);
    box-shadow: var(--shadow);
    color: var(--ink);
    font-weight: 700;
    font-size: 1.0625rem;
    text-decoration: none;
    transition: transform 180ms cubic-bezier(0.3, 1.4, 0.5, 1), box-shadow 180ms;
    animation: rise 420ms cubic-bezier(0.2, 1.2, 0.4, 1) backwards;
  }
  .rows a:nth-child(2) { animation-delay: 60ms; }
  .rows a:nth-child(3) { animation-delay: 120ms; }
  .rows a:nth-child(4) { animation-delay: 180ms; }
  .rows a:nth-child(5) { animation-delay: 240ms; }
  .rows a:nth-child(n + 6) { animation-delay: 300ms; }
  .rows a:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-lift);
  }
  .rows a:active {
    transform: scale(0.98);
  }
  .icon {
    flex: none;
    display: grid;
    place-items: center;
    width: 48px;
    height: 48px;
    border-radius: 16px;
    background: var(--t, var(--peach));
    color: var(--i, var(--primary));
  }
  .text {
    flex: 1;
    min-width: 0;
  }
  .go {
    flex: none;
    color: #c79a88;
  }
  .links {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 16px;
  }
  .links a {
    display: inline-flex;
    align-items: center;
    min-height: 44px;
    padding: 8px 16px;
    border: 1px solid var(--line);
    border-radius: 999px;
    background: var(--surface);
    box-shadow: var(--shadow);
    color: var(--ink);
    font-size: 0.9375rem;
    font-weight: 600;
    text-decoration: none;
  }
  .powered {
    display: block;
    margin-top: 32px;
    color: var(--muted);
    font-size: 0.8125rem;
    text-align: center;
  }
  @keyframes pop {
    from {
      opacity: 0;
      transform: scale(0.6);
    }
  }
  @keyframes rise {
    from {
      opacity: 0;
      transform: translateY(12px);
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .logo,
    .rows a {
      animation: none;
      transition: none;
    }
  }
</style>
