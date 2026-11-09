// Xotirada ishlaydigan demo: Supabase loyihasi ulanguncha saytni to'liq ko'rish uchun.
import { randomBytes, randomInt } from 'node:crypto';
import type { ActivePage, CardState, EarnedReward, MyCard, Plan, Profile, Visit } from '#lib/types.ts';
import type { Backend } from './backend';
import { DEMO_PAGES, demoTag } from './demo-data';

type Guest = { id: string; phone: string; name: string; locale: string };
type Member = {
  id: string;
  guestId: string;
  slug: string;
  stamps: number;
  cycle: number;
  marketing: boolean;
  active: boolean;
  rewards: (EarnedReward & { tierStamps: number; cycle: number })[];
  visits: Visit[];
};

const otps = new Map<string, { code: string; attempts: number; expires: number }>();
const otpSends = new Map<string, number[]>();
const feedbackAt = new Map<string, number>();
const guestsByPhone = new Map<string, Guest>();
const guestsById = new Map<string, Guest>();
const members = new Map<string, Member>();

const FEEDBACK_COOLDOWN_MS = 10 * 60 * 1000;
const OTP_MAX_PER_HOUR = 5;
const OTP_TTL_MS = 5 * 60 * 1000;

const activePage = (slug: string): ActivePage | null => {
  const page = DEMO_PAGES[slug];
  return page?.status === 'active' ? page : null;
};

const memberOf = (session: string, slug: string) => {
  const member = [...members.values()].find((m) => m.guestId === session && m.slug === slug);
  return member?.active ? member : undefined;
};

function cardState(member: Member): CardState {
  const page = activePage(member.slug)!;
  return {
    business_name: page.name,
    slug: page.slug,
    stamps: member.stamps,
    tiers: page.program?.tiers ?? [],
    rewards: member.rewards.map(({ id, title, expires_at }) => ({ id, title, expires_at }))
  };
}

export const demoBackend: Backend = {
  demo: true,

  async getPlans(): Promise<Plan[]> {
    return [
      { id: 'free', name: 'Bepul', price_uzs: 0 },
      { id: 'start', name: 'Start', price_uzs: 149000 },
      { id: 'pro', name: 'Pro', price_uzs: 349000 },
      { id: 'network', name: 'Tarmoq', price_uzs: null }
    ];
  },

  async getPage(slug, tag) {
    const page = DEMO_PAGES[slug];
    if (!page) return null;
    if (page.status !== 'active') return page;
    return { ...page, tag: tag ? demoTag(tag) : null };
  },

  async demoTags(_slug, count) {
    return Array.from({ length: count }, (_, index) => ({ code: `S${index + 1}`, table_label: String(index + 1) }));
  },

  async logEvent(slug, action, tag) {
    console.info(`[demo] event ${slug} ${action} tag=${tag ?? '-'}`);
  },

  async submitFeedback(slug, deviceKey, input) {
    const key = `${slug}:${deviceKey}`;
    const last = feedbackAt.get(key);
    if (last && Date.now() - last < FEEDBACK_COOLDOWN_MS) return 'rate_limited';
    feedbackAt.set(key, Date.now());
    console.info(`[demo] feedback ${slug} rating=${input.rating}`);
    return 'ok';
  },

  async requestDemo(input) {
    console.info(`[demo] demo request from ${input.business_name}`);
  },

  async sendOtp(phone) {
    const hourAgo = Date.now() - 3_600_000;
    const recent = (otpSends.get(phone) ?? []).filter((at) => at > hourAgo);
    if (recent.length >= OTP_MAX_PER_HOUR) return { ok: false, error: 'rate_limited' };
    otpSends.set(phone, [...recent, Date.now()]);
    const code = String(randomInt(1000, 10000));
    otps.set(phone, { code, attempts: 0, expires: Date.now() + OTP_TTL_MS });
    return { ok: true, devCode: code };
  },

  async verifyOtp(phone, code) {
    const entry = otps.get(phone);
    if (!entry || entry.expires < Date.now() || entry.attempts >= 5) return null;
    entry.attempts++;
    if (entry.code !== code) return null;
    otps.delete(phone);
    let guest = guestsByPhone.get(phone);
    if (!guest) {
      guest = { id: randomBytes(16).toString('hex'), phone, name: '', locale: 'uz' };
      guestsByPhone.set(phone, guest);
      guestsById.set(guest.id, guest);
    }
    return guest.id;
  },

  async getProfile(session): Promise<Profile | null> {
    const guest = guestsById.get(session);
    return guest ? { name: guest.name, phone: guest.phone, locale: guest.locale } : null;
  },

  async join(session, slug, input) {
    const guest = guestsById.get(session);
    if (!guest || !input.terms || !activePage(slug)?.program) return false;
    if (input.name) guest.name = input.name;
    const existing = [...members.values()].find((m) => m.guestId === session && m.slug === slug);
    if (existing) {
      existing.active = true;
      existing.marketing = input.marketing;
      return true;
    }
    const id = randomBytes(8).toString('hex');
    members.set(id, { id, guestId: session, slug, stamps: 0, cycle: 0, marketing: input.marketing, active: true, rewards: [], visits: [] });
    return true;
  },

  async getCard(session, slug) {
    const member = memberOf(session, slug);
    return member ? cardState(member) : null;
  },

  async issueCardToken(session, slug) {
    if (!memberOf(session, slug)) return null;
    return { token: `TEGIO-DEMO-${randomBytes(18).toString('base64url')}`, expiresAt: Math.floor(Date.now() / 1000) + 60 };
  },

  async myCards(session): Promise<MyCard[]> {
    return [...members.values()]
      .filter((m) => m.guestId === session && m.active)
      .map((m) => ({ ...cardState(m), membership_id: m.id, marketing_consent: m.marketing }));
  },

  async visits(session) {
    return [...members.values()]
      .filter((m) => m.guestId === session)
      .flatMap((m) => m.visits)
      .sort((a, b) => b.at.localeCompare(a.at));
  },

  async updateProfile(session, input) {
    const guest = guestsById.get(session);
    if (guest) Object.assign(guest, input);
  },

  async setMarketing(session, membershipId, consent) {
    const member = members.get(membershipId);
    if (member?.guestId === session) member.marketing = consent;
  },

  async leaveProgram(session, membershipId) {
    const member = members.get(membershipId);
    if (member?.guestId === session) {
      member.active = false;
      member.marketing = false;
    }
  },

  async deleteAccount(session) {
    const guest = guestsById.get(session);
    if (!guest) return;
    guestsById.delete(session);
    guestsByPhone.delete(guest.phone);
    for (const [id, member] of members) if (member.guestId === session) members.delete(id);
  },

  async demoStamp(session, slug) {
    const member = memberOf(session, slug);
    const page = activePage(slug);
    if (!member || !page?.program) return;
    member.stamps++;
    member.visits.push({ at: new Date().toISOString(), kind: 'stamp', business_name: page.name });
    for (const tier of page.program.tiers) {
      const earned = member.rewards.some((r) => r.tierStamps === tier.stamps_required && r.cycle === member.cycle);
      if (member.stamps >= tier.stamps_required && !earned) {
        member.rewards.push({ id: randomBytes(8).toString('hex'), title: tier.title, expires_at: null, tierStamps: tier.stamps_required, cycle: member.cycle });
      }
    }
    const top = Math.max(...page.program.tiers.map((t) => t.stamps_required));
    if (member.stamps >= top) {
      member.stamps -= top;
      member.cycle++;
    }
  }
};
