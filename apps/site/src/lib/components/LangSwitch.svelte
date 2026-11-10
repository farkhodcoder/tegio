<script lang="ts">
  import { page } from '$app/state';
  import { LOCALES, LOCALE_LABELS } from '#lib/i18n.ts';
</script>

<form method="POST" action="/api/lang" class="lang" data-sveltekit-reload>
  <input type="hidden" name="to" value={page.url.pathname + page.url.search} />
  {#each LOCALES as locale (locale)}
    <button name="locale" value={locale} lang={locale} aria-current={page.data.locale === locale ? 'true' : undefined}>
      {LOCALE_LABELS[locale]}
    </button>
  {/each}
</form>

<style>
  .lang {
    display: flex;
    gap: 2px;
  }
  button {
    min-width: 40px;
    min-height: 40px;
    border: 0;
    border-radius: 10px;
    background: transparent;
    color: inherit;
    font: inherit;
    font-size: 0.875rem;
    cursor: pointer;
  }
  button[aria-current] {
    background: color-mix(in srgb, currentColor 16%, transparent);
    font-weight: 700;
  }
</style>
