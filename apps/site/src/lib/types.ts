// public_page() SQL funksiyasi qaytaradigan JSON shakli.
export type I18nMap = Record<string, string>;

export type MenuSchedule = { days?: number[]; from: string; to: string };

export type PublicMenuItem = {
  id: string;
  price_uzs: number;
  photo_url: string | null;
  tags: string[];
  available: boolean;
  i18n: I18nMap | null;
};

export type PublicCategory = { id: string; i18n: I18nMap | null; items: PublicMenuItem[] };

export type PublicMenu = {
  id: string;
  name: string;
  i18n?: I18nMap | null;
  schedule: MenuSchedule | null;
  categories: PublicCategory[];
};

export type LandingItem = { kind: string; label: string | null; url: string | null };

export type RewardTier = { stamps_required: number; title: string };

export type ActivePage = {
  status: 'active';
  name: string;
  slug: string;
  brand: { primary?: string; tagline?: string; logo_url?: string; cover_url?: string };
  show_branding: boolean;
  tag: { id: string; table_label: string | null } | null;
  location: {
    id: string;
    name: string;
    address: string | null;
    timezone: string;
    google_review_url: string | null;
    wifi_ssid: string | null;
    wifi_password: string | null;
  };
  items: LandingItem[];
  program: { card: Record<string, unknown>; tiers: RewardTier[] } | null;
  menus: PublicMenu[];
};

export type InactivePage = { status: 'payment_stopped' | 'blocked' | 'hidden'; name: string; slug: string };

export type PublicPage = ActivePage | InactivePage;

export type Plan = { id: string; name: string; price_uzs: number | null };

export type EarnedReward = { id: string; title: string; expires_at: string | null };

export type CardState = {
  business_name: string;
  slug: string;
  stamps: number;
  tiers: RewardTier[];
  rewards: EarnedReward[];
};

export type Visit = { at: string; kind: 'stamp' | 'redeem'; business_name: string };

export type Profile = { name: string; phone: string; locale: string; };

export type MyCard = CardState & { membership_id: string; marketing_consent: boolean };
