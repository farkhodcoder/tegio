<script lang="ts">
  import SubHeader from '#lib/components/SubHeader.svelte';
  import { defaultMenuId, formatPrice, matchesFilters, matchesSearch, translate, type Filter } from '#lib/menu.ts';
  import type { ActivePage, PublicMenuItem } from '#lib/types.ts';

  let { data } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);
  const locale = $derived(data.locale);

  const FILTERS: Filter[] = ['halal', 'spicy', 'vegetarian', 'no_nuts', 'no_dairy', 'no_gluten'];

  // svelte-ignore state_referenced_locally
  let selectedId = $state(defaultMenuId((data.cafe as ActivePage).menus, new Date(), (data.cafe as ActivePage).location.timezone));
  let query = $state('');
  let active = $state<Filter[]>([]);

  const menu = $derived(cafe.menus.find((x) => x.id === selectedId));

  function toggle(filter: Filter) {
    active = active.includes(filter) ? active.filter((f) => f !== filter) : [...active, filter];
  }

  function visible(item: PublicMenuItem): boolean {
    return (
      matchesFilters(item.tags, active) &&
      matchesSearch([translate(item.i18n, 'name', locale), translate(item.i18n, 'description', locale)], query)
    );
  }

  const sections = $derived(
    (menu?.categories ?? [])
      .map((category) => ({ category, items: category.items.filter(visible) }))
      .filter((section) => section.items.length)
  );

  const TAG_LABEL: Record<string, keyof typeof m> = { halal: 'f_halal', spicy: 'f_spicy', vegetarian: 'f_vegetarian' };
</script>

<svelte:head><title>{m.btn_menu} · {cafe.name}</title></svelte:head>

<SubHeader title={cafe.name} />

<main class="page">
  {#if !cafe.menus.length}
    <p class="muted">{m.menu_none}</p>
  {:else}
    {#if cafe.menus.length > 1}
      <div class="tabs" role="tablist">
        {#each cafe.menus as item (item.id)}
          <button role="tab" aria-selected={item.id === selectedId} onclick={() => (selectedId = item.id)}>{translate(item.i18n, 'name', locale) || item.name}</button>
        {/each}
      </div>
    {/if}

    <input type="search" bind:value={query} placeholder={m.menu_search} aria-label={m.menu_search} />

    <div class="chips">
      {#each FILTERS as filter (filter)}
        <button aria-pressed={active.includes(filter)} onclick={() => toggle(filter)}>{m[`f_${filter}`]}</button>
      {/each}
    </div>

    {#each sections as { category, items } (category.id)}
      <section>
        <h2>{translate(category.i18n, 'name', locale)}</h2>
        <ul>
          {#each items as item (item.id)}
            <li class:out={!item.available}>
              {#if item.photo_url}
                <img src={item.photo_url} alt="" loading="lazy" width="72" height="72" />
              {/if}
              <div class="info">
                <h3>{translate(item.i18n, 'name', locale)}</h3>
                <p class="desc">{translate(item.i18n, 'description', locale)}</p>
                <p class="meta">
                  {translate(item.i18n, 'portion', locale)}{#each item.tags.filter((t) => TAG_LABEL[t]) as tag (tag)}
                    <span>{m[TAG_LABEL[tag]]}</span>{/each}
                </p>
              </div>
              <div class="price">
                {#if item.available}
                  {formatPrice(item.price_uzs)}<small>{m.som}</small>
                {:else}
                  <b>{m.sold_out}</b>
                {/if}
              </div>
            </li>
          {/each}
        </ul>
      </section>
    {:else}
      <p class="muted">{m.menu_empty}</p>
    {/each}
  {/if}
</main>

<style>
  .tabs {
    display: flex;
    gap: 4px;
    margin-bottom: 12px;
    padding: 4px;
    border-radius: 12px;
    background: var(--line);
  }
  .tabs button {
    flex: 1;
    min-height: 44px;
    border: 0;
    border-radius: 9px;
    background: transparent;
    color: var(--ink);
    font: inherit;
    font-weight: 600;
    cursor: pointer;
  }
  .tabs button[aria-selected='true'] {
    background: var(--surface);
    font-weight: 700;
  }
  .chips {
    display: flex;
    gap: 6px;
    margin: 10px -16px 0;
    padding: 2px 16px;
    overflow-x: auto;
    scrollbar-width: none;
  }
  .chips button {
    flex: none;
    min-height: 40px;
    padding: 6px 14px;
    border: 1.5px solid var(--line);
    border-radius: 999px;
    background: var(--surface);
    color: var(--ink);
    font: inherit;
    font-size: 0.9375rem;
    cursor: pointer;
  }
  .chips button[aria-pressed='true'] {
    border-color: var(--biz);
    background: var(--biz);
    color: var(--on-biz);
  }
  h2 {
    margin: 24px 0 2px;
    font: 500 1.125rem/1.3 var(--display);
  }
  ul {
    margin: 0;
    padding: 0;
    list-style: none;
  }
  li {
    display: flex;
    gap: 12px;
    padding: 14px 0;
    border-bottom: 1px solid var(--line);
  }
  li img {
    flex: none;
    border-radius: 10px;
    object-fit: cover;
  }
  .info {
    flex: 1;
    min-width: 0;
  }
  h3 {
    margin: 0;
    font-size: 1.0625rem;
    font-weight: 700;
  }
  .desc {
    margin: 2px 0 0;
    color: var(--muted);
    font-size: 0.9375rem;
  }
  .meta {
    margin: 4px 0 0;
    color: var(--muted);
    font-size: 0.8125rem;
  }
  .meta span {
    margin-left: 8px;
    color: var(--accent);
    font-weight: 700;
  }
  .price {
    flex: none;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    text-align: right;
  }
  .price small {
    display: block;
    color: var(--muted);
    font-size: 0.75rem;
    font-weight: 400;
  }
  .price b {
    color: var(--danger);
    font-size: 0.875rem;
  }
  .out h3,
  .out .desc {
    color: var(--muted);
    text-decoration: line-through;
  }
</style>
