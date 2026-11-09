<script lang="ts">
  import { page } from '$app/state';
  const m = $derived(page.data.m);
</script>

<svelte:head><title>TEGIO</title></svelte:head>

<main class="page stack">
  {#if page.status === 404}
    <h1>{m?.not_found ?? '404'}</h1>
    <p class="muted">{m?.not_found_sub ?? ''}</p>
  {:else}
    <h1>{m?.error_generic ?? 'Error'}</h1>
  {/if}
  <a class="btn" href="/">{m?.home ?? 'TEGIO'}</a>
</main>
