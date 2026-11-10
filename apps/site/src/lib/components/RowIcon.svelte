<script lang="ts">
  // Kafe sahifasidagi tugma belgilari: to'la rangli, yumshoq doira ichida.
  let { kind }: { kind: string } = $props();
</script>

<svg viewBox="0 0 24 24" width="24" height="24" aria-hidden="true">
  {#if kind === 'loyalty'}
    <path d="M12 21s-8.5-5.2-8.5-11.4A4.9 4.9 0 0 1 12 6.4a4.9 4.9 0 0 1 8.5 3.2C20.5 15.8 12 21 12 21Z" fill="#E0245E" />
  {:else if kind === 'google'}
    <path d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3Z" fill="#4285F4" />
    <path d="M12 22c2.7 0 5-.9 6.6-2.4l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22Z" fill="#34A853" />
    <path d="M6.4 14a6 6 0 0 1 0-4V7.4H3.1a10 10 0 0 0 0 9.2L6.4 14Z" fill="#FBBC05" />
    <path d="M12 5.9c1.5 0 2.8.5 3.8 1.5l2.9-2.9A10 10 0 0 0 3.1 7.4L6.4 10C7.2 7.7 9.4 5.9 12 5.9Z" fill="#EA4335" />
  {:else if kind === 'menu'}
    <path d="M6 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z" fill="#F08C00" />
    <path d="M18 7h1a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1h-1Z" fill="#C46A00" />
    <path d="M8.5 8h6M8.5 11.5h6M8.5 15h4" stroke="#FFE8C2" stroke-width="1.8" stroke-linecap="round" />
  {:else if kind === 'wifi'}
    <path d="M2.5 9a14 14 0 0 1 19 0M5.8 12.6a9 9 0 0 1 12.4 0M9 16.2a4.4 4.4 0 0 1 6 0" fill="none" stroke="#2F9E44" stroke-width="2.4" stroke-linecap="round" />
    <circle cx="12" cy="19.6" r="1.7" fill="#2F9E44" />
  {:else if kind === 'feedback'}
    <rect x="3" y="4" width="18" height="5" rx="1.5" fill="#4C6EF5" />
    <path d="M4.5 10h15v8.5a1.5 1.5 0 0 1-1.5 1.5H6a1.5 1.5 0 0 1-1.5-1.5Z" fill="#748FFC" />
    <rect x="9" y="12.5" width="6" height="2" rx="1" fill="#EDF2FF" />
  {:else if kind === 'game'}
    {#each [6, 12, 18] as y (y)}
      {#each [6, 12, 18] as x (x)}
        <rect x={x - 2.2} y={y - 2.2} width="4.4" height="4.4" rx="1.2" fill="#7048E8" />
      {/each}
    {/each}
  {:else}
    <circle cx="12" cy="12" r="8" fill="var(--primary)" />
  {/if}
</svg>
