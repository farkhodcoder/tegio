import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-tegio-session, x-tegio-ip',
  'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
};

export function json(body: unknown, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders, ...headers },
  });
}

export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing env: ${name}`);
  return value;
}

export function serviceClient(): SupabaseClient {
  return createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false },
  });
}

// JWT'ni Supabase Auth orqali tekshiradi; foydalanuvchi id'sini RPC'ga shu yerdan beramiz.
export async function authenticatedUserId(req: Request, db: SupabaseClient): Promise<string | null> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data, error } = await db.auth.getUser(token);
  return error ? null : (data.user?.id ?? null);
}

const secrets = new Map<string, string>();

// Ichki kalitlar Vault'da; Edge Function sirlari orqali almashtirish ham mumkin.
export async function internalSecret(db: SupabaseClient, name: string): Promise<string> {
  const fromEnv = Deno.env.get(name.toUpperCase());
  if (fromEnv) return fromEnv;
  const cached = secrets.get(name);
  if (cached) return cached;
  const { data, error } = await db.rpc('internal_secret', { p_name: name });
  if (error || !data) throw new Error(`Missing secret: ${name}`);
  secrets.set(name, data);
  return data;
}
