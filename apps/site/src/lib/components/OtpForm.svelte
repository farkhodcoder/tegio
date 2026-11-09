<script lang="ts">
  import { enhance } from '$app/forms';
  import { page } from '$app/state';
  import { fmt } from '#lib/i18n.ts';

  type OtpResult = { phone?: string; devCode?: string; otpError?: string } | null | undefined;
  let { result }: { result: OtpResult } = $props();
  const m = $derived(page.data.m);
</script>

{#if result?.phone && result?.otpError !== 'phone' && result?.otpError !== 'rate'}
  <form method="POST" action="?/verify" use:enhance class="stack">
    <p>{fmt(m.card_code_sent, { phone: result.phone })}</p>
    {#if result.devCode}
      <p class="note">{fmt(m.card_demo_code, { code: result.devCode })}</p>
    {/if}
    <input type="hidden" name="phone" value={result.phone} />
    <label>
      {m.card_code}
      <input name="code" inputmode="numeric" autocomplete="one-time-code" required maxlength="6" aria-invalid={result.otpError === 'code'} />
    </label>
    {#if result.otpError === 'code'}<p class="error" role="alert">{m.card_bad_code}</p>{/if}
    <button class="btn">{m.card_verify}</button>
  </form>
{:else}
  <form method="POST" action="?/send" use:enhance class="stack">
    <label>
      {m.field_phone}
      <span class="phone">
        <span>+998</span>
        <input name="phone" type="tel" inputmode="tel" autocomplete="tel-national" placeholder="90 123 45 67" required aria-invalid={result?.otpError === 'phone'} />
      </span>
    </label>
    {#if result?.otpError === 'phone'}<p class="error" role="alert">{m.card_bad_phone}</p>{/if}
    {#if result?.otpError === 'rate'}<p class="error" role="alert">{m.card_rate}</p>{/if}
    {#if result?.otpError === 'sms'}<p class="error" role="alert">{m.card_sms_down}</p>{/if}
    <button class="btn">{m.card_phone_send}</button>
  </form>
{/if}

<style>
  .phone {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 600;
  }
  .phone input {
    flex: 1;
    min-width: 0;
  }
</style>
