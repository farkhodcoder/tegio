<script lang="ts">
  import { page } from '$app/state';

  let { title }: { title: string } = $props();
  const back = $derived(`/${page.params.slug}${page.url.search}`);
</script>

<header class="sub">
  <a href={back} aria-label={page.data.m.back}>
    <svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true"><path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" /></svg>
  </a>
  <h1>{title}</h1>
</header>

<style>
  .sub {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 8px 8px 8px 4px;
    background: var(--biz);
    color: var(--on-biz);
  }
  a {
    display: grid;
    place-items: center;
    width: 44px;
    height: 44px;
    color: inherit;
  }
  h1 {
    margin: 0;
    font: 500 1.125rem/1.2 var(--display);
  }
</style>
