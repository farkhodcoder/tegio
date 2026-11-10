<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import LangSwitch from '#lib/components/LangSwitch.svelte';
  import { fmt } from '#lib/i18n.ts';
  import { safeHttpUrl } from '#lib/links.ts';
  import type { ActivePage, LandingItem } from '#lib/types.ts';

  let { data } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);
  const tagCode = $derived(page.url.searchParams.get('t'));

  const INTERNAL: Record<string, string> = { menu: 'menu', wifi: 'wifi', loyalty: 'karta', feedback: 'fikr' };

  const ICONS: Record<string, string> = {
    menu: 'M6 3v6a3 3 0 0 0 6 0V3M9 3v18M18 21V3c-2.2 1-3.5 4-3.5 9H18',
    wifi: 'M2.5 9a14 14 0 0 1 19 0M5.8 12.8a9 9 0 0 1 12.4 0M9 16.4a4.2 4.2 0 0 1 6 0M12 20h.01',
    loyalty: 'M12 20s-7.5-4.6-7.5-10.2A4.2 4.2 0 0 1 12 7.3a4.2 4.2 0 0 1 7.5 2.5C19.5 15.4 12 20 12 20Z',
    feedback: 'M4 5h16v11H9l-5 4V5Z',
    google: 'M12 3.5l2.6 5.6 6 .7-4.5 4.1 1.2 6-5.3-3-5.3 3 1.2-6L3.4 9.8l6-.7L12 3.5Z'
  };

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
    return (m as Record<string, string>)[`btn_${item.kind}`] ?? item.kind;
  }

  const internal = $derived(cafe.items.filter((i) => INTERNAL[i.kind]));
  const external = $derived(cafe.items.filter((i) => !INTERNAL[i.kind]));
  const initials = $derived(cafe.name.slice(0, 1).toLocaleUpperCase());

  type Row = { kind: string; href: string; text: string; external: boolean };

  const rows = $derived.by(() => {
    const list: Row[] = internal.map((item) => ({ kind: item.kind, href: href(item), text: label(item), external: false }));
    // F-03, F-04: qator bahoga bog'liq emas va hech qanday mukofot bermaydi.
    const google = safeHttpUrl(cafe.location.google_review_url);
    if (google) {
      const feedback = list.findIndex((row) => row.kind === 'feedback');
      list.splice(feedback < 0 ? list.length : feedback + 1, 0, { kind: 'google', href: google, text: m.fb_google_title, external: true });
    }
    return list;
  });
</script>

<svelte:head>
  <title>{cafe.name}</title>
  <meta name="description" content={cafe.brand.tagline ?? cafe.name} />
</svelte:head>

<header class="cover" style={cafe.brand.cover_url ? `background-image:url(${JSON.stringify(cafe.brand.cover_url)})` : undefined}>
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
  <div class="logo">
    {#if cafe.brand.logo_url}
      <img src={cafe.brand.logo_url} alt="" width="84" height="84" />
    {:else}
      <span aria-hidden="true">{initials}</span>
    {/if}
  </div>
  <h1>{cafe.name}</h1>
  {#if cafe.brand.tagline}<p class="tagline">{cafe.brand.tagline}</p>{/if}
  <p class="where">
    {cafe.location.name}{#if cafe.tag?.table_label}{' · '}{fmt(m.table, { n: cafe.tag.table_label })}{/if}
  </p>

  <nav class="rows">
    {#each rows as row (row.kind)}
      <a href={row.href} target={row.external ? '_blank' : undefined} rel={row.external ? 'noopener' : undefined} onclick={() => track(row.kind)}>
        <span class="icon" style={`--t:var(--t-${row.kind});--i:var(--i-${row.kind})`}>
          <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path d={ICONS[row.kind]} fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /></svg>
        </span>
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
    height: 188px;
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
  .logo {
    display: grid;
    place-items: center;
    width: 96px;
    height: 96px;
    margin-top: -66px;
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
    margin: 14px 0 4px;
    font: 600 1.85rem/1.15 var(--display);
  }
  .tagline {
    margin: 0;
    color: var(--muted);
    font-size: 1.0625rem;
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
