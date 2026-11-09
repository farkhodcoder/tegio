import type { CardState, MyCard, Plan, Profile, PublicPage, Visit } from '#lib/types.ts';
import { demoBackend } from './demo';

export type FeedbackInput = { rating: number; text: string; contact: string; tag: string | null };

export interface Backend {
  readonly demo: boolean;
  getPlans(): Promise<Plan[]>;
  getPage(slug: string, tag: string | null): Promise<PublicPage | null>;
  logEvent(slug: string, action: string, tag: string | null): Promise<void>;
  submitFeedback(slug: string, deviceKey: string, input: FeedbackInput): Promise<'ok' | 'rate_limited'>;
  requestDemo(input: { name: string; phone: string; business_name: string }): Promise<void>;
  sendOtp(phone: string): Promise<{ ok: true; devCode?: string } | { ok: false; error: 'rate_limited' }>;
  verifyOtp(phone: string, code: string): Promise<string | null>;
  getProfile(session: string): Promise<Profile | null>;
  join(session: string, slug: string, input: { name: string; terms: boolean; marketing: boolean }): Promise<boolean>;
  getCard(session: string, slug: string): Promise<CardState | null>;
  issueCardToken(session: string, slug: string): Promise<{ token: string; expiresAt: number } | null>;
  myCards(session: string): Promise<MyCard[]>;
  visits(session: string): Promise<Visit[]>;
  updateProfile(session: string, input: { name: string; locale: string }): Promise<void>;
  setMarketing(session: string, membershipId: string, consent: boolean): Promise<void>;
  leaveProgram(session: string, membershipId: string): Promise<void>;
  deleteAccount(session: string): Promise<void>;
  demoStamp?(session: string, slug: string): Promise<void>;
  // Himoyasiz, shuning uchun faqat demo'da. Haqiqiy B-08 restoran tizimida, kirish bilan.
  demoTags?(slug: string, count: number): Promise<{ code: string; table_label: string }[]>;
}

// Supabase loyihasi ulanganda shu yerda Edge Functions'ga boradigan amalga almashtiriladi.
export const backend: Backend = demoBackend;

export const SESSION_COOKIE = 'tegio_session';
export const DEVICE_COOKIE = 'tegio_device';
