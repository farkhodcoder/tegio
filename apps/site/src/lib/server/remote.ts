// Supabase Edge Function `api` bilan ishlaydigan haqiqiy backend.
import type { CardState, MyCard, Plan, Profile, PublicPage, Visit } from '#lib/types.ts';
import type { Backend } from './backend';

const TIMEOUT_MS = 10_000;
const NO_CONTENT = new Set([401, 404]);
const CONTENT_TTL_MS = 60_000;

type CallOptions = { method?: string; session?: string; body?: unknown; ip?: string };

export function remoteBackend(baseUrl: string): Backend {
  const base = baseUrl.replace(/\/$/, '');

  async function send(path: string, { method = 'GET', session, body, ip }: CallOptions = {}): Promise<Response> {
    const headers: Record<string, string> = {};
    if (body !== undefined) headers['content-type'] = 'application/json';
    if (session) headers['x-tegio-session'] = session;
    if (ip) headers['x-tegio-ip'] = ip;
    return fetch(`${base}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS)
    });
  }

  // Kutilgan "yo'q" javoblari null bo'ladi; qolgan xatolar sahifada 500 sifatida ko'rinadi.
  async function read<T>(path: string, options?: CallOptions): Promise<T | null> {
    const response = await send(path, options);
    if (NO_CONTENT.has(response.status)) return null;
    if (!response.ok) throw new Error(`TEGIO API ${response.status} ${path.split('?')[0]}`);
    return response.json();
  }

  const slugQuery = (slug: string) => `?slug=${encodeURIComponent(slug)}`;
  const contentCache = new Map<string, { at: number; value: Record<string, string> }>();

  return {
    demo: false,

    // Har sahifaga qo'shimcha so'rov bo'lmasin; API javob bermasa, kod ichidagi matnlar qoladi.
    async getContent(locale) {
      const cached = contentCache.get(locale);
      if (cached && Date.now() - cached.at < CONTENT_TTL_MS) return cached.value;
      const value = await read<Record<string, string>>(`/content?locale=${encodeURIComponent(locale)}`).catch(() => null);
      const content = value ?? cached?.value ?? {};
      contentCache.set(locale, { at: Date.now(), value: content });
      return content;
    },

    async getPlans() {
      const plans = (await read<Plan[]>('/plans')) ?? [];
      // Tarmoq tarifining narxi kelishuv bo'yicha: bazada 0, sahifada "kelishiladi".
      return plans
        .map((plan) => ({ ...plan, price_uzs: plan.price_uzs === 0 && plan.id !== 'free' ? null : plan.price_uzs }))
        .sort((a, b) => (a.price_uzs ?? Infinity) - (b.price_uzs ?? Infinity));
    },

    getPage(slug, tag) {
      const query = tag ? `?t=${encodeURIComponent(tag)}` : '';
      return read<PublicPage>(`/public/${encodeURIComponent(slug)}${query}`);
    },

    async logEvent(slug, action, tag, device) {
      await send('/public/event', { method: 'POST', body: { slug, action, tag, device } }).catch(() => undefined);
    },

    async submitFeedback(slug, deviceKey, input) {
      const result = await read<{ ok: boolean; error?: string }>('/feedback', {
        method: 'POST',
        body: { slug, device: deviceKey, ...input }
      });
      return result?.ok ? 'ok' : 'rate_limited';
    },

    async requestDemo(input, ip) {
      const response = await send('/public/demo-request', { method: 'POST', body: input, ip });
      if (!response.ok && response.status !== 429) throw new Error(`TEGIO API ${response.status} demo-request`);
    },

    async sendOtp(phone, ip) {
      const response = await send('/guest/otp/send', { method: 'POST', body: { phone }, ip });
      const result = await response.json();
      if (result.ok) return { ok: true, devCode: result.dev_code };
      return { ok: false, error: response.status === 429 ? 'rate_limited' : 'sms_unavailable' };
    },

    async verifyOtp(phone, code) {
      const response = await send('/guest/otp/verify', { method: 'POST', body: { phone, code } });
      if (response.status === 400 || response.status === 401) return null;
      if (!response.ok) throw new Error(`TEGIO API ${response.status} otp-verify`);
      return (await response.json()).session ?? null;
    },

    getProfile: (session) => read<Profile>('/me', { session }),

    async join(session, slug, input) {
      const result = await read<{ ok: boolean }>('/me/join', { method: 'POST', session, body: { slug, ...input } });
      return !!result?.ok;
    },

    getCard: (session, slug) => read<CardState>(`/me/card${slugQuery(slug)}`, { session }),

    async issueCardToken(session, slug) {
      const result = await read<{ ok: boolean; token: string; expiresAt: number }>(`/guest/card-token${slugQuery(slug)}`, { session });
      return result?.ok ? { token: result.token, expiresAt: result.expiresAt } : null;
    },

    myCards: async (session) => (await read<MyCard[]>('/me/cards', { session })) ?? [],
    visits: async (session) => (await read<Visit[]>('/me/visits', { session })) ?? [],

    async updateProfile(session, input) {
      await read('/me', { method: 'PATCH', session, body: input });
    },

    async setMarketing(session, membershipId, consent) {
      await read('/me/marketing', { method: 'POST', session, body: { membership_id: membershipId, consent } });
    },

    async leaveProgram(session, membershipId) {
      await read('/me/leave', { method: 'POST', session, body: { membership_id: membershipId } });
    },

    async deleteAccount(session) {
      await read('/me', { method: 'DELETE', session });
    }
  };
}
