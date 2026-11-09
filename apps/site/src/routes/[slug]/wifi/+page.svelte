<script lang="ts">
  import SubHeader from '#lib/components/SubHeader.svelte';
  import type { ActivePage } from '#lib/types.ts';

  let { data } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);
  let copied = $state(false);
  let timer: ReturnType<typeof setTimeout>;

  async function copy() {
    await navigator.clipboard.writeText(cafe.location.wifi_password ?? '');
    copied = true;
    clearTimeout(timer);
    timer = setTimeout(() => (copied = false), 2500);
  }
</script>

<svelte:head><title>{m.btn_wifi} · {cafe.name}</title></svelte:head>

<SubHeader title={m.btn_wifi} />

<main class="page stack">
  {#if cafe.location.wifi_ssid}
    <div class="panel">
      <p class="label">{m.wifi_network}</p>
      <p class="value">{cafe.location.wifi_ssid}</p>
      {#if cafe.location.wifi_password}
        <p class="label">{m.wifi_password}</p>
        <p class="value">{cafe.location.wifi_password}</p>
      {/if}
    </div>
    {#if cafe.location.wifi_password}
      <button class="btn" onclick={copy} aria-live="polite">{copied ? m.wifi_copied : m.wifi_copy}</button>
    {/if}
    <p class="muted">{m.wifi_steps}</p>
  {:else}
    <p class="muted">{m.wifi_none}</p>
  {/if}
</main>

<style>
  .label {
    margin: 0;
    color: var(--muted);
    font-size: 0.875rem;
  }
  .value {
    margin: 0 0 12px;
    font-size: 1.25rem;
    font-weight: 700;
    overflow-wrap: anywhere;
  }
  .value:last-child {
    margin-bottom: 0;
  }
</style>
