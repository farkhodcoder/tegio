<script lang="ts">
  import { safeHttpUrl } from '#lib/links.ts';
  import { enhance } from '$app/forms';
  import SubHeader from '#lib/components/SubHeader.svelte';
  import { fmt } from '#lib/i18n.ts';
  import type { ActivePage } from '#lib/types.ts';

  let { data, form } = $props();
  const m = $derived(data.m);
  const cafe = $derived(data.cafe as ActivePage);
  const googleUrl = $derived(safeHttpUrl(cafe.location.google_review_url));
</script>

<svelte:head><title>{m.btn_feedback} · {cafe.name}</title></svelte:head>

<SubHeader title={m.btn_feedback} />

<main class="page stack">
  {#if form?.sent}
    <p class="ok" role="status">{m.fb_thanks}</p>
  {:else}
    <h2>{m.fb_title}</h2>
    <form method="POST" use:enhance class="stack">
      <fieldset>
        <legend>{m.fb_rating}</legend>
        <div class="rating">
          {#each [1, 2, 3, 4, 5] as n (n)}
            <label>
              <input type="radio" name="rating" value={n} aria-label={fmt(m.fb_star, { n })} />
              <span aria-hidden="true">{n}</span>
            </label>
          {/each}
        </div>
      </fieldset>
      {#if form?.error === 'rating'}<p class="error" role="alert">{m.fb_need_rating}</p>{/if}
      {#if form?.error === 'limited'}<p class="error" role="alert">{m.fb_limited}</p>{/if}
      <label>{m.fb_text}<textarea name="text" rows="4" maxlength="2000"></textarea></label>
      <label>{m.fb_contact}<input name="contact" maxlength="200" /></label>
      <button class="btn">{m.fb_send}</button>
    </form>
  {/if}

  <!-- F-03: bu blok bahoga bog'liq emas, hamma uchun bir xil. -->
  {#if googleUrl}
    <a class="google panel" href={googleUrl} target="_blank" rel="noopener">
      <strong>{m.fb_google_title}</strong>
      <span class="muted">{m.fb_google_sub}</span>
    </a>
  {/if}
</main>

<style>
  h2 {
    margin: 0;
    font: 500 1.375rem/1.25 var(--display);
  }
  fieldset {
    margin: 0;
    padding: 0;
    border: 0;
  }
  legend {
    margin-bottom: 8px;
    padding: 0;
    font-weight: 600;
  }
  .rating {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 8px;
  }
  .rating label {
    position: relative;
    display: block;
  }
  .rating input {
    position: absolute;
    opacity: 0;
    inset: 0;
    margin: 0;
    width: 100%;
    height: 100%;
    cursor: pointer;
  }
  .rating span {
    display: grid;
    place-items: center;
    height: 56px;
    border: 1.5px solid var(--muted);
    border-radius: 12px;
    background: var(--surface);
    font: 500 1.25rem var(--display);
  }
  .rating input:checked + span {
    border-color: var(--biz);
    background: var(--biz);
    color: var(--on-biz);
  }
  .rating input:focus-visible + span {
    outline: 3px solid var(--accent);
    outline-offset: 2px;
  }
  .google {
    display: grid;
    gap: 2px;
    color: var(--ink);
    text-decoration: none;
  }
</style>
