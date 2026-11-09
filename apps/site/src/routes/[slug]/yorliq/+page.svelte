<script lang="ts">
  import SubHeader from '#lib/components/SubHeader.svelte';
  import { fmt } from '#lib/i18n.ts';
  import type { ActivePage } from '#lib/types.ts';

  let { data } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);
  let showWifi = $state(true);

  // TTZ 3-bo'lim: qog'ozdagi yozuv UzQR to'lov kodidan farq qilishi kerak, shuning uchun brauzer tiliga bog'liq emas.
  const LABEL = { title: 'Menyu va bonus', scan: 'Kamera bilan skanerlang', table: 'Stol', wifi: 'Wi-Fi ga ulanish', notPayment: 'Toʻlov uchun emas' };
</script>

<svelte:head>
  <title>{m.tags_title} · {cafe.name}</title>
  <meta name="robots" content="noindex" />
</svelte:head>

<div class="no-print"><SubHeader title={m.tags_title} /></div>

<main class="sheet">
  <section class="controls no-print stack">
    <p>{m.tags_sub}</p>
    {#if data.localOnly}
      <p class="note">{fmt(m.tags_local, { origin: data.origin })}</p>
    {/if}
    <form method="get" class="count">
      <label>
        {m.tags_count}
        <input name="n" type="number" min="1" max={data.maxTables} value={data.count} required />
      </label>
      <button class="btn ghost" type="submit">{m.tags_apply}</button>
    </form>
    {#if data.wifiQr}
      <label class="check"><input type="checkbox" bind:checked={showWifi} /> {m.tags_wifi}</label>
    {/if}
    <button class="btn" type="button" onclick={() => window.print()}>{m.tags_print}</button>
  </section>

  <div class="tags">
    {#each data.tags as tag (tag.code)}
      <div class="item">
        <article class="tag">
          <header>{cafe.name}</header>
          <h2>{LABEL.title}</h2>
          <!-- eslint-disable-next-line svelte/no-at-html-tags -- uqr chiqishi, foydalanuvchi matni emas -->
          <div class="qr">{@html tag.qr}</div>
          <p class="scan">{LABEL.scan}</p>
          <p class="table">{LABEL.table} {tag.table_label}</p>
          {#if data.wifiQr && showWifi}
            <div class="wifi">
              <!-- eslint-disable-next-line svelte/no-at-html-tags -- uqr chiqishi, foydalanuvchi matni emas -->
              <div class="qr small">{@html data.wifiQr}</div>
              <p><strong>{LABEL.wifi}</strong><br />{data.wifiSsid}</p>
            </div>
          {/if}
          <footer>{LABEL.notPayment}</footer>
        </article>
        <p class="nfc no-print">{m.tags_nfc}<br /><code>{tag.link}</code></p>
      </div>
    {/each}
  </div>
</main>

<style>
  .sheet {
    max-width: 760px;
    margin: 0 auto;
    padding: 16px;
  }
  .controls {
    margin-bottom: 20px;
  }
  .controls p {
    margin: 0;
  }
  .count {
    display: flex;
    align-items: flex-end;
    gap: 10px;
  }
  .count label {
    flex: 1;
    min-width: 0;
  }
  .tags {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(min(100%, 300px), 1fr));
    gap: 20px;
  }
  .item {
    min-width: 0;
  }
  .tag {
    display: flex;
    flex-direction: column;
    align-items: center;
    overflow: hidden;
    border: 1px solid var(--line);
    border-radius: var(--radius);
    background: #fff;
    color: #101a38;
    text-align: center;
  }
  .tag header {
    width: 100%;
    padding: 10px 12px;
    background: var(--biz);
    color: var(--on-biz);
    font: 500 1.0625rem var(--display);
    overflow-wrap: anywhere;
  }
  h2 {
    margin: 14px 8px 2px;
    font: 500 1.5rem/1.15 var(--display);
  }
  .qr {
    width: 72%;
    line-height: 0;
  }
  .qr :global(svg) {
    width: 100%;
    height: auto;
  }
  .qr.small {
    flex: none;
    width: 76px;
  }
  .scan {
    margin: 0;
    color: #515c7a;
    font-size: 0.875rem;
  }
  .table {
    margin: 6px 0 10px;
    font: 500 1.25rem var(--display);
  }
  .wifi {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 6px 14px;
    border-top: 1px solid #d8e0ec;
    text-align: left;
    font-size: 0.875rem;
  }
  .wifi p {
    min-width: 0;
    margin: 0;
    overflow-wrap: anywhere;
  }
  footer {
    width: 100%;
    padding: 6px;
    border-top: 1px solid #d8e0ec;
    font-size: 0.8125rem;
    font-weight: 700;
  }
  .nfc {
    margin: 8px 0 0;
    color: var(--muted);
    font-size: 0.8125rem;
    overflow-wrap: anywhere;
  }

  @page {
    size: A4;
    margin: 10mm;
  }
  @media print {
    .no-print {
      display: none;
    }
    :global(html),
    :global(body) {
      background: #fff;
    }
    .sheet {
      max-width: none;
      padding: 0;
    }
    .tags {
      grid-template-columns: repeat(2, 92mm);
      justify-content: space-between;
      gap: 5mm 0;
    }
    .tag {
      height: 134mm;
      justify-content: space-between;
      break-inside: avoid;
      border-color: #9aa5bd;
      print-color-adjust: exact;
      -webkit-print-color-adjust: exact;
    }
    .item {
      break-inside: avoid;
    }
    .qr {
      width: 62mm;
    }
    .qr.small {
      width: 21mm;
    }
  }
</style>
