<script lang="ts">
  import { isHexColor, readableOn } from '#lib/brand.ts';

  let { data, children } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe);
  const primary = $derived(cafe.status === 'active' && isHexColor(cafe.brand.primary) ? cafe.brand.primary : null);
</script>

<svelte:head>
  {#if cafe.status !== 'active'}<title>{cafe.name}</title>{/if}
</svelte:head>

<div class="cafe" style={primary ? `--biz:${primary};--on-biz:${readableOn(primary)}` : undefined}>
  {#if cafe.status === 'active'}
    {@render children()}
  {:else}
    <main class="page stack">
      <p class="muted">{cafe.name}</p>
      <h1>{cafe.status === 'payment_stopped' ? m.inactive_payment : m.inactive_blocked}</h1>
      <p>{cafe.status === 'payment_stopped' ? m.inactive_payment_sub : m.inactive_blocked_sub}</p>
    </main>
  {/if}
</div>

<style>
  .cafe {
    min-height: 100dvh;
  }
  h1 {
    margin: 0;
    font: 500 1.5rem/1.25 var(--display);
  }
</style>
