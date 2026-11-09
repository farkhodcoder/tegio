-- TEGIO: ma'lumotlar modeli (TTZ 9-bo'lim).
-- Har bir biznes jadvalida business_id bor; farzand jadvallar ota jadvalga
-- (id, business_id) kompozit kaliti bilan bog'lanadi, shuning uchun qator
-- boshqa biznesga tegishli otaga ulana olmaydi.

create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

create type public.staff_role as enum ('owner', 'manager', 'cashier');
create type public.admin_role as enum ('super_admin', 'support', 'finance');
create type public.business_status as enum ('active', 'payment_stopped', 'blocked', 'hidden');
create type public.tag_type as enum ('qr', 'nfc');

create table public.plans (
  id text primary key,
  name text not null,
  price_uzs integer not null check (price_uzs >= 0),
  limits_json jsonb not null default '{}',
  modules_json jsonb not null default '{}'
);

insert into public.plans (id, name, price_uzs, limits_json, modules_json) values
  ('free', 'Bepul', 0, '{"locations": 1}', '{"menu": true, "wifi": true}'),
  ('start', 'Start', 149000, '{"locations": 1}',
   '{"menu": true, "wifi": true, "loyalty": true, "wallet": true, "feedback": true, "stats": true}'),
  ('pro', 'Pro', 349000, '{"locations": 3}',
   '{"menu": true, "wifi": true, "loyalty": true, "wallet": true, "feedback": true, "stats": true, "ai": true, "broadcast": true, "telegram": true, "remove_branding": true}'),
  ('network', 'Tarmoq', 0, '{"locations": null}',
   '{"menu": true, "wifi": true, "loyalty": true, "wallet": true, "feedback": true, "stats": true, "ai": true, "broadcast": true, "telegram": true, "remove_branding": true, "api": true}');

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique
    check (slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'
       and slug not in ('me', 'api', 'admin', 'biz', 'www', 'app', 'static', 'shartlar', 'maxfiylik')),
  owner_id uuid not null references auth.users (id),
  plan text not null default 'free' references public.plans (id),
  brand_json jsonb not null default '{}',
  status public.business_status not null default 'active',
  status_reason text,
  city text,
  created_at timestamptz not null default now()
);

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null,
  address text,
  lat double precision,
  lng double precision,
  timezone text not null default 'Asia/Tashkent',
  wifi_ssid text,
  wifi_password_enc bytea,
  google_review_url text,
  created_at timestamptz not null default now(),
  unique (id, business_id)
);

create table public.staff_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  location_id uuid,
  user_id uuid not null references auth.users (id),
  role public.staff_role not null,
  status text not null default 'active' check (status in ('active', 'removed')),
  created_at timestamptz not null default now(),
  unique (business_id, user_id),
  unique (id, business_id),
  foreign key (location_id, business_id) references public.locations (id, business_id)
);
create index staff_members_user_idx on public.staff_members (user_id) where status = 'active';

create table public.tag_batches (
  id uuid primary key default gen_random_uuid(),
  type public.tag_type not null,
  quantity integer not null check (quantity > 0),
  created_by uuid,
  created_at timestamptz not null default now()
);

-- Yorliq partiyada biznessiz yaratilib, keyin biriktirilishi mumkin (P-16, P-17).
create table public.tags (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  business_id uuid references public.businesses (id) on delete set null,
  location_id uuid,
  table_label text,
  type public.tag_type not null default 'qr',
  batch_id uuid references public.tag_batches (id),
  created_at timestamptz not null default now(),
  foreign key (location_id, business_id) references public.locations (id, business_id)
);

create table public.landing_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  location_id uuid not null,
  kind text not null,
  label text,
  url text,
  position integer not null default 0,
  enabled boolean not null default true,
  foreign key (location_id, business_id) references public.locations (id, business_id) on delete cascade
);
create index landing_items_location_idx on public.landing_items (location_id, position);

create table public.menus (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null,
  position integer not null default 0,
  schedule_json jsonb,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  unique (id, business_id)
);

create table public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  menu_id uuid not null,
  position integer not null default 0,
  unique (id, business_id),
  foreign key (menu_id, business_id) references public.menus (id, business_id) on delete cascade
);

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  category_id uuid not null,
  price_uzs integer not null check (price_uzs >= 0),
  photo_url text,
  tags text[] not null default '{}',
  available boolean not null default true,
  position integer not null default 0,
  foreign key (category_id, business_id) references public.menu_categories (id, business_id) on delete cascade
);
create index menu_items_category_idx on public.menu_items (category_id, position);

-- Taom va kategoriya nomlari shu yerda: name, description, portion (M-05, B-14).
create table public.translations (
  business_id uuid not null references public.businesses (id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  field text not null,
  locale text not null check (locale in ('uz', 'uz-Cyrl', 'ru', 'en')),
  value text not null,
  primary key (entity_type, entity_id, field, locale)
);
create index translations_business_idx on public.translations (business_id);

create table public.loyalty_programs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null unique references public.businesses (id) on delete cascade,
  stamp_interval_min integer not null default 60 check (stamp_interval_min >= 0),
  stamp_expiry_days integer check (stamp_expiry_days > 0),
  card_json jsonb not null default '{}',
  enabled boolean not null default false,
  unique (id, business_id)
);

create table public.reward_tiers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  program_id uuid not null,
  stamps_required integer not null check (stamps_required > 0),
  title text not null,
  expiry_days integer check (expiry_days > 0),
  unique (program_id, stamps_required),
  unique (id, business_id),
  foreign key (program_id, business_id) references public.loyalty_programs (id, business_id) on delete cascade
);

create table public.guests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  phone text not null unique check (phone ~ '^\+[0-9]{9,15}$'),
  name text,
  birthday date,
  locale text check (locale in ('uz', 'uz-Cyrl', 'ru', 'en')),
  created_at timestamptz not null default now()
);

-- guest_id NULL: mehmon ma'lumotini o'chirgan. Jurnal butun qoladi, lekin
-- endi hech kimga bog'lanmaydi (B-28 va U-06 birga bajariladi).
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  guest_id uuid references public.guests (id) on delete set null,
  program_id uuid not null,
  stamps integer not null default 0 check (stamps >= 0),
  cycle integer not null default 0,
  terms_accepted_at timestamptz not null,
  marketing_consent boolean not null default false,
  consent_at timestamptz,
  status text not null default 'active' check (status in ('active', 'left', 'deleted')),
  created_at timestamptz not null default now(),
  unique (guest_id, program_id),
  unique (id, business_id),
  foreign key (program_id, business_id) references public.loyalty_programs (id, business_id)
);
create index memberships_business_idx on public.memberships (business_id);

create table public.stamp_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  membership_id uuid not null,
  location_id uuid not null,
  staff_id uuid not null,
  delta integer not null,
  reason text not null default 'stamp'
    check (reason in ('stamp', 'cycle_reset', 'expiry', 'redeem')),
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  foreign key (membership_id, business_id) references public.memberships (id, business_id),
  foreign key (location_id, business_id) references public.locations (id, business_id),
  foreign key (staff_id, business_id) references public.staff_members (id, business_id)
);
create index stamp_events_membership_idx on public.stamp_events (membership_id, created_at desc);
create index stamp_events_business_idx on public.stamp_events (business_id, created_at desc);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  membership_id uuid not null,
  tier_id uuid not null,
  cycle integer not null default 0,
  status text not null default 'available' check (status in ('available', 'redeemed', 'expired')),
  earned_at timestamptz not null default now(),
  expires_at timestamptz,
  redeemed_at timestamptz,
  unique (membership_id, tier_id, cycle),
  foreign key (membership_id, business_id) references public.memberships (id, business_id),
  foreign key (tier_id, business_id) references public.reward_tiers (id, business_id)
);

create table public.wallet_passes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  membership_id uuid not null,
  platform text not null check (platform in ('apple', 'google')),
  serial text not null unique,
  device_token text,
  updated_at timestamptz not null default now(),
  foreign key (membership_id, business_id) references public.memberships (id, business_id) on delete cascade
);

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  location_id uuid not null,
  tag_id uuid references public.tags (id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  text text check (char_length(text) <= 2000),
  contact text,
  status text not null default 'new' check (status in ('new', 'in_progress', 'resolved', 'archived')),
  reply text,
  created_at timestamptz not null default now(),
  foreign key (location_id, business_id) references public.locations (id, business_id) on delete cascade
);
create index feedback_business_idx on public.feedback (business_id, created_at desc);

create table public.scan_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  tag_id uuid references public.tags (id) on delete set null,
  location_id uuid not null,
  action text not null,
  created_at timestamptz not null default now()
);
create index scan_events_business_idx on public.scan_events (business_id, created_at desc);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  plan text not null references public.plans (id),
  status text not null check (status in ('trial', 'active', 'past_due', 'cancelled')),
  period_end timestamptz not null,
  provider text
);
create index subscriptions_business_idx on public.subscriptions (business_id);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id),
  amount_uzs integer not null check (amount_uzs >= 0),
  provider text not null check (provider in ('click', 'payme', 'cash', 'bank')),
  provider_txn_id text,
  status text not null check (status in ('pending', 'paid', 'failed', 'refunded')),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (provider, provider_txn_id)
);

create table public.admin_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users (id),
  email text not null unique,
  role public.admin_role not null,
  totp_enabled boolean not null default false,
  status text not null default 'invited' check (status in ('invited', 'active', 'disabled'))
);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  action text not null,
  entity text not null,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);

create table public.demo_requests (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  business_name text,
  status text not null default 'new' check (status in ('new', 'contacted', 'won', 'lost')),
  assignee_id uuid references public.admin_users (id),
  note text,
  created_at timestamptz not null default now()
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  subject text not null,
  status text not null default 'open' check (status in ('open', 'pending', 'closed')),
  assignee_id uuid references public.admin_users (id),
  created_at timestamptz not null default now()
);

create table public.site_content (
  key text not null,
  locale text not null check (locale in ('uz', 'uz-Cyrl', 'ru', 'en')),
  value text not null,
  updated_by uuid,
  primary key (key, locale)
);

create table public.feature_flags (
  key text not null,
  scope text not null check (scope in ('global', 'business')),
  business_id uuid references public.businesses (id) on delete cascade,
  enabled boolean not null default false,
  unique nulls not distinct (key, business_id)
);

-- Ishlatilgan karta QR tokenlari: QR ikkinchi marta ishlamaydi.
create table public.used_card_tokens (
  jti text primary key,
  used_at timestamptz not null default now()
);

-- SMS, fikr va skan limitlari.
create table public.rate_limits (
  key text not null,
  window_start timestamptz not null,
  count integer not null default 0,
  primary key (key, window_start)
);

-- Faqat qo'shiladigan jurnallar: hatto service_role ham o'zgartira olmaydi.
create function private.reject_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception '% faqat qo''shiladi', tg_table_name using errcode = '42501';
end;
$$;

create trigger stamp_events_append_only before update or delete on public.stamp_events
  for each row execute function private.reject_mutation();
create trigger stamp_events_no_truncate before truncate on public.stamp_events
  for each statement execute function private.reject_mutation();
create trigger audit_log_append_only before update or delete on public.audit_log
  for each row execute function private.reject_mutation();
create trigger audit_log_no_truncate before truncate on public.audit_log
  for each statement execute function private.reject_mutation();
