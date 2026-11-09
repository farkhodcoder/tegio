// Migratsiyalarni haqiqiy Postgres'da (PGlite) ishga tushiradi. Docker kerak emas.
// auth sxemasi va rollar Supabase'dagidek stub qilinadi.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const migrationsDir = join(import.meta.dirname, '..', 'migrations');

const SUPABASE_STUB = `
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create schema extensions;
  create table auth.users (id uuid primary key default gen_random_uuid(), phone text, phone_confirmed_at timestamptz);
  create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;
  create schema vault;
  create table vault.secrets (name text primary key, decrypted_secret text not null);
  create view vault.decrypted_secrets as select name, decrypted_secret from vault.secrets;
  create function vault.create_secret(p_value text, p_name text) returns void language sql as
    $$ insert into vault.secrets values (p_name, p_value) $$;
  create schema cron;
  create function cron.schedule(text, text, text) returns bigint language sql as 'select 1::bigint';
  create schema storage;
  create table storage.buckets (id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (bucket_id text, name text);
  create function storage.foldername(p_name text) returns text[] language sql immutable as $$ select string_to_array(p_name, '/') $$;
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant usage on schema public, auth, extensions to anon, authenticated, service_role;
  grant execute on function auth.uid(), auth.jwt() to anon, authenticated, service_role;
  grant execute on all functions in schema extensions to service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`;

export type Role = 'anon' | 'authenticated' | 'service_role';

export class Db {
  readonly pg: PGlite;

  constructor(pg: PGlite) {
    this.pg = pg;
  }

  async sql<T = Record<string, unknown>>(query: string, params: unknown[] = []): Promise<T[]> {
    return (await this.pg.query<T>(query, params)).rows;
  }

  // So'rovni berilgan rol va JWT bilan bajaradi, keyin superuser'ga qaytadi.
  async as<T = Record<string, unknown>>(
    role: Role,
    userId: string | null,
    query: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    await this.pg.exec(`select set_config('request.jwt.claim.sub', '${userId ?? ''}', false); set role ${role};`);
    try {
      return await this.sql<T>(query, params);
    } finally {
      await this.pg.exec(`reset role; select set_config('request.jwt.claim.sub', '', false);`);
    }
  }

  async rpc<T = any>(name: string, args: unknown[]): Promise<T> {
    const placeholders = args.map((_, i) => `$${i + 1}`).join(', ');
    const rows = await this.as<{ result: T }>('service_role', null, `select public.${name}(${placeholders}) as result`, args);
    return rows[0].result;
  }

  async newUser(): Promise<string> {
    const [row] = await this.sql<{ id: string }>('insert into auth.users (phone_confirmed_at) values (now()) returning id');
    return row.id;
  }
}

export async function createDb(): Promise<Db> {
  const pg = new PGlite({ extensions: { pgcrypto } });
  await pg.exec(SUPABASE_STUB);
  for (const file of readdirSync(migrationsDir).sort()) {
    // Bu ikki kengaytma PGlite'da yo'q, ularning sxemalari yuqorida stub qilingan.
    await pg.exec(readFileSync(join(migrationsDir, file), 'utf8').replace(/create extension if not exists (supabase_vault|pg_cron)[^;]*;/g, ''));
  }
  return new Db(pg);
}

export type Tenant = {
  businessId: string;
  locationId: string;
  programId: string;
  owner: string;
  manager: string;
  cashier: string;
  categoryId: string;
};

let slugCounter = 0;

export async function createTenant(db: Db, intervalMin = 60): Promise<Tenant> {
  const owner = await db.newUser();
  const manager = await db.newUser();
  const cashier = await db.newUser();
  const slug = `kafe-${++slugCounter}`;
  const [{ id: businessId }] = await db.as<{ id: string }>(
    'authenticated', owner, `select public.create_business($1, $2, 'Markaz') as id`, [slug, slug],
  );
  const [{ id: locationId }] = await db.sql<{ id: string }>('select id from public.locations where business_id = $1', [businessId]);
  const [{ id: programId }] = await db.sql<{ id: string }>(
    'update public.loyalty_programs set enabled = true, stamp_interval_min = $2 where business_id = $1 returning id',
    [businessId, intervalMin],
  );
  await db.sql(
    `insert into public.staff_members (business_id, user_id, role) values ($1, $2, 'manager'), ($1, $3, 'cashier')`,
    [businessId, manager, cashier],
  );
  await db.sql(
    `insert into public.reward_tiers (business_id, program_id, stamps_required, title)
     values ($1, $2, 2, 'Pishiriq'), ($1, $2, 3, 'Qahva')`,
    [businessId, programId],
  );
  const [{ id: menuId }] = await db.sql<{ id: string }>(
    `insert into public.menus (business_id, name, status) values ($1, 'Asosiy', 'published') returning id`, [businessId],
  );
  const [{ id: categoryId }] = await db.sql<{ id: string }>(
    'insert into public.menu_categories (business_id, menu_id) values ($1, $2) returning id', [businessId, menuId],
  );
  await db.sql('insert into public.menu_items (business_id, category_id, price_uzs) values ($1, $2, 15000)', [businessId, categoryId]);
  return { businessId, locationId, programId, owner, manager, cashier, categoryId };
}

let phoneCounter = 0;

export async function joinGuest(db: Db, tenant: Tenant, marketing = false) {
  const user = await db.newUser();
  const phone = `+99890${String(1000000 + ++phoneCounter)}`;
  const [{ slug }] = await db.sql<{ slug: string }>('select slug from public.businesses where id = $1', [tenant.businessId]);
  const result = await db.rpc('join_program', [user, phone, slug, 'Mehmon', true, marketing]);
  return { user, phone, membershipId: result.membership_id as string };
}
