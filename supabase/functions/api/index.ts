// TEGIO API (TTZ 9-bo'lim). verify_jwt o'chiq: har bir yo'l o'z kirishini tekshiradi.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';
import { crypto as stdCrypto } from 'jsr:@std/crypto@1';
import { encodeHex } from 'jsr:@std/encoding@1/hex';
import { signCardToken, verifyCardToken } from '../_shared/card_token.ts';
import { authenticatedUserId, corsHeaders, internalSecret, json, requireEnv, serviceClient } from '../_shared/http.ts';
import { signSession, verifySession } from '../_shared/session.ts';

const PHONE_RE = /^\+998\d{9}$/;
const AI_DAILY_LIMIT = 30;
const AI_MODEL = 'claude-opus-5-5';

type Body = Record<string, unknown>;
const str = (v: unknown, max = 500) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
const connectionIp = (req: Request) => (req.headers.get('x-forwarded-for') ?? 'unknown').split(',')[0].trim();
const rpcFail = (name: string, code?: string) => {
  console.error(`${name} failed`, code);
  return json({ ok: false, error: 'server_error' }, 500);
};

async function sendSms(phone: string, text: string): Promise<boolean> {
  const email = Deno.env.get('ESKIZ_EMAIL');
  const password = Deno.env.get('ESKIZ_PASSWORD');
  if (!email || !password) return false;
  const login = await fetch('https://notify.eskiz.uz/api/auth/login', {
    method: 'POST',
    body: new URLSearchParams({ email, password }),
  });
  if (!login.ok) return false;
  const token = (await login.json()).data?.token;
  const sent = await fetch('https://notify.eskiz.uz/api/message/sms/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: new URLSearchParams({
      mobile_phone: phone.slice(1),
      message: text,
      from: Deno.env.get('ESKIZ_FROM') ?? '4546',
    }),
  });
  return sent.ok;
}

async function notifyTelegram(chatId: string, text: string): Promise<void> {
  const token = Deno.env.get('TELEGRAM_BOT_TOKEN');
  if (!token) return;
  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text }),
  }).catch(() => undefined);
}

async function userIdForPhone(db: SupabaseClient, phone: string): Promise<string | null> {
  const { data } = await db.rpc('auth_user_id_by_phone', { p_phone: phone });
  if (data) return data;
  const created = await db.auth.admin.createUser({
    phone,
    phone_confirm: true,
    email: `${phone.slice(1)}@phone.tegio.uz`,
    email_confirm: true,
  });
  return created.data.user?.id ?? null;
}

async function staffSession(db: SupabaseClient, phone: string) {
  const link = await db.auth.admin.generateLink({ type: 'magiclink', email: `${phone.slice(1)}@phone.tegio.uz` });
  const hash = link.data.properties?.hashed_token;
  if (!hash) return null;
  const anon = createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_ANON_KEY'), { auth: { persistSession: false } });
  const { data } = await anon.auth.verifyOtp({ token_hash: hash, type: 'magiclink' });
  return data.session;
}

async function otpSend(db: SupabaseClient, req: Request, body: Body): Promise<Response> {
  const phone = str(body.phone, 20);
  if (!PHONE_RE.test(phone)) return json({ ok: false, error: 'bad_phone' }, 400);
  // x-tegio-ip'ni sayt serveri yuboradi, lekin uni boshqa mijoz ham yozishi mumkin:
  // shuning uchun haqiqiy ulanish manzili bo'yicha alohida, kengroq chegara bor.
  const connection = connectionIp(req);
  const { data: connectionOk } = await db.rpc('check_rate_limit', { p_key: `otp-conn:${connection}`, p_window_seconds: 3600, p_max: 300 });
  const { data: ipOk } = await db.rpc('check_rate_limit', {
    p_key: `otp-ip:${req.headers.get('x-tegio-ip') ?? connection}`, p_window_seconds: 3600, p_max: 30,
  });
  if (!connectionOk || !ipOk) return json({ ok: false, error: 'rate_limited' }, 429);

  const code = String(100000 + (crypto.getRandomValues(new Uint32Array(1))[0] % 900000));
  const { data: allowed, error } = await db.rpc('otp_issue', { p_phone: phone, p_code: code });
  if (error) return rpcFail('otp_issue', error.code);
  if (!allowed) return json({ ok: false, error: 'rate_limited' }, 429);

  // Kod faqat aniq yoqilgan sinov rejimida javobga chiqadi; odatiy holatda SMS kerak.
  if (Deno.env.get('OTP_DEV_MODE') === 'true') return json({ ok: true, dev_code: code });
  const template = Deno.env.get('SMS_TEMPLATE') ?? 'TEGIO tasdiqlash kodi: {code}';
  if (!(await sendSms(phone, template.replace('{code}', code)))) {
    return json({ ok: false, error: 'sms_unavailable' }, 503);
  }
  await db.from('usage_events').insert({ kind: 'sms' });
  return json({ ok: true });
}

async function otpVerify(db: SupabaseClient, body: Body): Promise<Response> {
  const phone = str(body.phone, 20);
  const code = str(body.code, 6);
  if (!PHONE_RE.test(phone) || !code) return json({ ok: false, error: 'bad_code' }, 400);
  const { data: valid, error } = await db.rpc('otp_verify', { p_phone: phone, p_code: code });
  if (error) return rpcFail('otp_verify', error.code);
  if (!valid) return json({ ok: false, error: 'bad_code' }, 401);

  const userId = await userIdForPhone(db, phone);
  if (!userId) return json({ ok: false, error: 'server_error' }, 500);

  if (body.client === 'biz') {
    const session = await staffSession(db, phone);
    if (!session) return json({ ok: false, error: 'server_error' }, 500);
    return json({ ok: true, access_token: session.access_token, refresh_token: session.refresh_token });
  }
  await db.rpc('ensure_guest', { p_user_id: userId, p_phone: phone });
  return json({ ok: true, session: await signSession(userId, phone, await internalSecret(db, 'session_secret')) });
}

async function guestRoute(db: SupabaseClient, req: Request, route: string, url: URL, body: Body): Promise<Response> {
  const session = await verifySession(req.headers.get('x-tegio-session'), await internalSecret(db, 'session_secret'));
  if (!session) return json({ ok: false, error: 'unauthorized' }, 401);
  const uid = session.uid;
  const slug = url.searchParams.get('slug') ?? '';
  const rpc = async (name: string, args: Body) => {
    const { data, error } = await db.rpc(name, args);
    return error ? rpcFail(name, error.code) : json(data ?? null);
  };

  switch (route) {
    case 'GET /me': return rpc('guest_profile', { p_user_id: uid });
    case 'GET /me/cards': return rpc('guest_cards', { p_user_id: uid });
    case 'GET /me/visits': return rpc('guest_visits', { p_user_id: uid });
    case 'GET /me/card': return rpc('guest_card', { p_user_id: uid, p_slug: slug });
    case 'PATCH /me':
      return rpc('guest_update_profile', { p_user_id: uid, p_name: str(body.name, 80), p_locale: str(body.locale, 8) });
    case 'DELETE /me': {
      const result = await db.rpc('delete_guest', { p_user_id: uid });
      if (result.error) return rpcFail('delete_guest', result.error.code);
      await db.auth.admin.deleteUser(uid);
      return json({ ok: true });
    }
    case 'POST /me/join':
      return rpc('join_program', {
        p_user_id: uid, p_phone: session.phone, p_slug: str(body.slug, 40), p_name: str(body.name, 80) || null,
        p_accept_terms: body.terms === true, p_marketing: body.marketing === true,
      });
    case 'POST /me/marketing':
      return rpc('guest_set_marketing', { p_user_id: uid, p_membership_id: str(body.membership_id, 40), p_consent: body.consent === true });
    case 'POST /me/leave':
      return rpc('leave_program', { p_user_id: uid, p_membership_id: str(body.membership_id, 40) });
    case 'POST /me/deletion-request': {
      // Raqam faqat tasdiqlangan sessiyadan olinadi: boshqa odamnikini so'rab bo'lmaydi (P-21).
      const { error } = await db.from('deletion_requests').insert({ phone: session.phone });
      return error ? rpcFail('deletion_request', error.code) : json({ ok: true });
    }
    case 'GET /guest/card-token': {
      const { data: mid } = await db.rpc('guest_membership_for_token', { p_user_id: uid, p_slug: slug });
      if (!mid) return json({ ok: false, error: 'card_not_found' }, 404);
      return json({ ok: true, ...(await signCardToken(mid, await internalSecret(db, 'card_token_secret'))) });
    }
  }
  return json({ ok: false, error: 'not_found' }, 404);
}

async function requireManager(db: SupabaseClient, userId: string, businessId: string): Promise<boolean> {
  const { data } = await db.from('staff_members').select('role')
    .eq('user_id', userId).eq('business_id', businessId).eq('status', 'active').in('role', ['owner', 'manager']).maybeSingle();
  return !!data;
}

async function staffStamp(db: SupabaseClient, userId: string, body: Body): Promise<Response> {
  const location = str(body.location_id, 40);
  const key = str(body.idempotency_key, 80);
  if (!location || !key) return json({ ok: false, error: 'bad_request' }, 400);

  let membershipId: string;
  let jti: string;
  if (typeof body.membership_id === 'string') {
    // Kamera ishlamaganda raqam orqali (B-26): jurnalda kim qo'yganini ko'rsatadi.
    membershipId = body.membership_id;
    jti = `manual:${key}`;
  } else {
    const verified = await verifyCardToken(str(body.token, 600), await internalSecret(db, 'card_token_secret'));
    if (!verified.ok) return json({ ok: false, error: verified.error });
    membershipId = verified.payload.mid;
    jti = verified.payload.jti;
  }
  const { data, error } = await db.rpc('apply_stamp', {
    p_user_id: userId, p_membership_id: membershipId, p_location_id: location, p_jti: jti, p_idempotency_key: key,
  });
  return error ? rpcFail('apply_stamp', error.code) : json(data);
}

async function paymentLink(db: SupabaseClient, userId: string, body: Body): Promise<Response> {
  const provider = str(body.provider, 10);
  if (provider !== 'click' && provider !== 'payme') return json({ ok: false, error: 'bad_request' }, 400);
  const clickService = Deno.env.get('CLICK_SERVICE_ID');
  const clickMerchant = Deno.env.get('CLICK_MERCHANT_ID');
  const paymeMerchant = Deno.env.get('PAYME_MERCHANT_ID');
  if (provider === 'click' ? !clickService || !clickMerchant : !paymeMerchant) {
    return json({ ok: false, error: 'provider_unavailable' }, 503);
  }
  const { data, error } = await db.rpc('create_payment', {
    p_user_id: userId, p_business_id: str(body.business_id, 40), p_plan: str(body.plan, 20), p_provider: provider,
  });
  if (error) return rpcFail('create_payment', error.code);
  if (!data.ok) return json(data, 400);
  const url = provider === 'click'
    ? `https://my.click.uz/services/pay?${new URLSearchParams({
        service_id: clickService!, merchant_id: clickMerchant!, amount: String(data.amount_uzs), transaction_param: data.payment_id,
      })}`
    : `https://checkout.paycom.uz/${btoa(`m=${paymeMerchant};ac.payment_id=${data.payment_id};a=${data.amount_uzs * 100}`)}`;
  return json({ ok: true, url });
}

const md5 = async (text: string) => encodeHex(await stdCrypto.subtle.digest('MD5', new TextEncoder().encode(text)));

async function clickWebhook(db: SupabaseClient, req: Request): Promise<Response> {
  const secret = requireEnv('CLICK_SECRET_KEY');
  const f = Object.fromEntries((await req.formData()).entries()) as Record<string, string>;
  const action = Number(f.action);
  const reply = (error: number, note: string, extra: Body = {}) =>
    json({ click_trans_id: f.click_trans_id, merchant_trans_id: f.merchant_trans_id, error, error_note: note, ...extra });

  const signed = action === 0
    ? `${f.click_trans_id}${f.service_id}${secret}${f.merchant_trans_id}${f.amount}${f.action}${f.sign_time}`
    : `${f.click_trans_id}${f.service_id}${secret}${f.merchant_trans_id}${f.merchant_prepare_id}${f.amount}${f.action}${f.sign_time}`;
  if ((await md5(signed)) !== f.sign_string) return reply(-1, 'SIGN CHECK FAILED');

  const { data: pay } = await db.rpc('get_payment', { p_payment_id: f.merchant_trans_id });
  if (!pay || pay.provider !== 'click') return reply(-5, 'Order not found');
  if (Number(f.amount) !== pay.amount_uzs) return reply(-2, 'Incorrect amount');
  if (action === 0) {
    if (pay.status === 'paid') return reply(-4, 'Already paid');
    return reply(0, 'Success', { merchant_prepare_id: pay.id });
  }
  if (Number(f.error) < 0) {
    await db.from('payments').update({ status: 'failed' }).eq('id', pay.id).eq('status', 'pending');
    return reply(-9, 'Transaction cancelled');
  }
  const { error } = await db.rpc('complete_payment', { p_payment_id: pay.id, p_provider_txn: f.click_trans_id });
  if (error) return reply(-7, 'Failed to update');
  return reply(0, 'Success', { merchant_confirm_id: pay.id });
}

async function paymeWebhook(db: SupabaseClient, req: Request): Promise<Response> {
  const rpcBody = await req.json().catch(() => ({}));
  const { id: rpcId, method, params = {} } = rpcBody;
  const ok = (result: unknown) => json({ jsonrpc: '2.0', id: rpcId, result });
  const fail = (code: number, message: string) => json({ jsonrpc: '2.0', id: rpcId, error: { code, message } });
  if (req.headers.get('Authorization') !== `Basic ${btoa(`Paycom:${requireEnv('PAYME_KEY')}`)}`) {
    return fail(-32504, 'Unauthorized');
  }
  const ms = (t: string | null) => (t ? new Date(t).getTime() : 0);
  const byTxn = async () =>
    (await db.from('payments').select('*').eq('provider', 'payme').eq('provider_txn_id', params.id).maybeSingle()).data;
  const state = (p: { status: string }) => (p.status === 'paid' ? 2 : p.status === 'failed' ? -1 : 1);

  if (method === 'CheckPerformTransaction' || method === 'CreateTransaction') {
    const { data: pay } = await db.rpc('get_payment', { p_payment_id: params.account?.payment_id ?? '' })
      .then((r) => r, () => ({ data: null }));
    if (!pay || pay.provider !== 'payme') return fail(-31050, 'Order not found');
    if (params.amount !== pay.amount_uzs * 100) return fail(-31001, 'Incorrect amount');
    if (pay.status !== 'pending') return fail(-31050, 'Order unavailable');
    if (method === 'CheckPerformTransaction') return ok({ allow: true });
    if (pay.provider_txn_id && pay.provider_txn_id !== params.id) return fail(-31050, 'Order busy');
    await db.from('payments').update({ provider_txn_id: params.id }).eq('id', pay.id);
    return ok({ create_time: ms(pay.created_at), transaction: pay.id, state: 1 });
  }
  if (method === 'GetStatement') {
    const { data } = await db.from('payments').select('*').eq('provider', 'payme').not('provider_txn_id', 'is', null)
      .gte('created_at', new Date(params.from).toISOString()).lte('created_at', new Date(params.to).toISOString());
    return ok({ transactions: (data ?? []).map((p) => ({
      id: p.provider_txn_id, time: ms(p.created_at), amount: p.amount_uzs * 100, account: { payment_id: p.id },
      create_time: ms(p.created_at), perform_time: ms(p.paid_at), cancel_time: 0, transaction: p.id, state: state(p), reason: null,
    })) });
  }
  const pay = await byTxn();
  if (!pay) return fail(-31003, 'Transaction not found');
  if (method === 'PerformTransaction') {
    if (pay.status === 'failed') return fail(-31008, 'Transaction cancelled');
    const { error } = await db.rpc('complete_payment', { p_payment_id: pay.id, p_provider_txn: params.id });
    if (error) return fail(-32400, 'Server error');
    const { data: fresh } = await db.rpc('get_payment', { p_payment_id: pay.id });
    return ok({ transaction: pay.id, perform_time: ms(fresh.paid_at), state: 2 });
  }
  if (method === 'CancelTransaction') {
    if (pay.status === 'paid') return fail(-31007, 'Already performed');
    await db.from('payments').update({ status: 'failed', note: `payme_reason:${params.reason}` }).eq('id', pay.id);
    return ok({ transaction: pay.id, cancel_time: ms(pay.created_at) + 1, state: -1 });
  }
  if (method === 'CheckTransaction') {
    return ok({
      create_time: ms(pay.created_at), perform_time: ms(pay.paid_at), cancel_time: pay.status === 'failed' ? ms(pay.created_at) + 1 : 0,
      transaction: pay.id, state: state(pay), reason: pay.status === 'failed' ? Number(String(pay.note).split(':')[1]) : null,
    });
  }
  return fail(-32601, 'Method not found');
}

const MENU_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['categories'],
  properties: {
    categories: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'items'],
        properties: {
          name: { type: 'string' },
          items: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['name', 'price_uzs', 'description'],
              properties: { name: { type: 'string' }, price_uzs: { type: 'integer' }, description: { type: 'string' } },
            },
          },
        },
      },
    },
  },
};

const TRANSLATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['uz_cyrl', 'ru', 'en'],
  properties: { uz_cyrl: { type: 'string' }, ru: { type: 'string' }, en: { type: 'string' } },
};

// Natija faqat qoralama: egasi tasdiqlagandan keyin e'lon qilinadi (B-14, B-15).
async function aiDraft(db: SupabaseClient, userId: string, route: string, body: Body): Promise<Response> {
  const businessId = str(body.business_id, 40);
  if (!(await requireManager(db, userId, businessId))) return json({ ok: false, error: 'forbidden' }, 403);
  if (!Deno.env.get('ANTHROPIC_API_KEY')) return json({ ok: false, error: 'ai_unavailable' }, 503);
  const { data: withinLimit } = await db.rpc('check_rate_limit', { p_key: `ai:${businessId}`, p_window_seconds: 86400, p_max: AI_DAILY_LIMIT });
  if (!withinLimit) return json({ ok: false, error: 'rate_limited' }, 429);

  const isImport = route === 'POST /ai/menu-import';
  const content = isImport
    ? [
        { type: 'image', source: { type: 'base64', media_type: str(body.media_type, 20), data: String(body.image_base64 ?? '') } },
        { type: 'text', text: "Read this restaurant menu photo. Return every category and dish exactly as printed. price_uzs is the price in Uzbek so'm as an integer, 0 if not visible. description is empty if not printed." },
      ]
    : [{ type: 'text', text: `Translate this restaurant menu text from Uzbek (Latin). Return Uzbek Cyrillic, Russian and English. Text: ${str(body.text, 500)}` }];

  const { default: Anthropic } = await import('npm:@anthropic-ai/sdk');
  const client = new Anthropic();
  const response = await client.beta.messages.create({
    model: AI_MODEL,
    max_tokens: isImport ? 16000 : 2000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'medium', format: { type: 'json_schema', schema: isImport ? MENU_SCHEMA : TRANSLATE_SCHEMA } },
    messages: [{ role: 'user', content }],
  } as never) as unknown as { stop_reason: string; content: { type: string; text?: string }[] };

  if (response.stop_reason === 'refusal' || response.stop_reason === 'max_tokens') {
    return json({ ok: false, error: 'ai_failed' }, 502);
  }
  const text = response.content.find((block) => block.type === 'text')?.text;
  if (!text) return json({ ok: false, error: 'ai_failed' }, 502);
  await db.from('usage_events').insert({ business_id: businessId, kind: 'ai' });
  return json({ ok: true, draft: JSON.parse(text) });
}

async function staffRoute(db: SupabaseClient, req: Request, route: string, body: Body): Promise<Response> {
  const userId = await authenticatedUserId(req, db);
  if (!userId) return json({ ok: false, error: 'unauthorized' }, 401);

  switch (route) {
    case 'POST /staff/stamp': return staffStamp(db, userId, body);
    case 'POST /staff/redeem': {
      const { data, error } = await db.rpc('redeem_reward', {
        p_user_id: userId, p_reward_id: str(body.reward_id, 40), p_location_id: str(body.location_id, 40),
      });
      return error ? rpcFail('redeem_reward', error.code) : json(data);
    }
    case 'POST /staff/find': {
      const { data, error } = await db.rpc('find_member_by_phone', {
        p_user_id: userId, p_business_id: str(body.business_id, 40), p_phone: str(body.phone, 20),
      });
      return error ? rpcFail('find_member_by_phone', error.code) : json(data);
    }
    case 'POST /biz/wifi': {
      const locationId = str(body.location_id, 40);
      const { data: location } = await db.from('locations').select('business_id').eq('id', locationId).maybeSingle();
      if (!location || !(await requireManager(db, userId, location.business_id))) return json({ ok: false, error: 'forbidden' }, 403);
      const { error } = await db.rpc('set_location_wifi', {
        p_location_id: locationId, p_ssid: str(body.ssid, 64) || null, p_password: str(body.password, 128) || null,
        p_key: await internalSecret(db, 'wifi_encryption_key'),
      });
      return error ? rpcFail('set_location_wifi', error.code) : json({ ok: true });
    }
    case 'POST /biz/pay': return paymentLink(db, userId, body);
    case 'POST /ai/menu-import':
    case 'POST /ai/translate':
      return aiDraft(db, userId, route, body);
    case 'POST /admin/invite': {
      const claims = JSON.parse(atob((req.headers.get('Authorization') ?? '').split('.')[1].replaceAll('-', '+').replaceAll('_', '/')));
      const { data: allowed } = await db.rpc('is_super_admin', { p_user_id: userId });
      if (!allowed || claims.aal !== 'aal2') return json({ ok: false, error: 'forbidden' }, 403);
      const email = str(body.email, 120);
      const invited = await db.auth.admin.inviteUserByEmail(email);
      if (invited.error || !invited.data.user) return json({ ok: false, error: 'invite_failed' }, 400);
      const { data } = await db.rpc('admin_invite_record', {
        p_actor: userId, p_user_id: invited.data.user.id, p_email: email, p_role: str(body.role, 20),
      });
      return json({ ok: !!data });
    }
  }
  return json({ ok: false, error: 'not_found' }, 404);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  const url = new URL(req.url);
  const parts = url.pathname.split('/').filter(Boolean);
  const path = parts.slice(parts.indexOf('api') + 1);
  const route = `${req.method} /${path.join('/')}`;
  const db = serviceClient();

  try {
    if (route === 'POST /webhooks/click') return await clickWebhook(db, req);
    if (route === 'POST /webhooks/payme') return await paymeWebhook(db, req);

    if (req.method === 'GET' && path[0] === 'public' && path[1]) {
      const { data, error } = await db.rpc('public_page', {
        p_slug: path[1], p_tag_code: url.searchParams.get('t'), p_wifi_key: await internalSecret(db, 'wifi_encryption_key'),
      });
      if (error) return rpcFail('public_page', error.code);
      if (!data) return json({ error: 'not_found' }, 404);
      return json(data, 200, { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=30' });
    }
    if (route === 'GET /content') {
      const { data } = await db.from('site_content').select('key,value').eq('locale', url.searchParams.get('locale') ?? 'uz');
      return json(Object.fromEntries((data ?? []).map((row) => [row.key, row.value])), 200, { 'Cache-Control': 'public, s-maxage=60' });
    }
    if (route === 'GET /plans') {
      const { data } = await db.from('plans').select('id,name,price_uzs').order('price_uzs');
      return json(data ?? [], 200, { 'Cache-Control': 'public, s-maxage=300' });
    }

    const body: Body = ['POST', 'PATCH'].includes(req.method) && !path[0]?.startsWith('webhooks')
      ? await req.json().catch(() => ({}))
      : {};

    switch (route) {
      case 'POST /guest/otp/send': return await otpSend(db, req, body);
      case 'POST /guest/otp/verify': return await otpVerify(db, body);
      case 'POST /public/event': {
        const device = str(body.device, 64) || 'unknown';
        const { data: allowed } = await db.rpc('check_rate_limit', { p_key: `scan:${device}`, p_window_seconds: 60, p_max: 60 });
        if (allowed) await db.rpc('log_scan', { p_slug: str(body.slug, 40), p_action: str(body.action, 40), p_tag_code: str(body.tag, 40) || null });
        return json({ ok: true });
      }
      case 'POST /public/demo-request': {
        const ip = req.headers.get('x-tegio-ip') ?? connectionIp(req);
        const { data: allowed } = await db.rpc('check_rate_limit', { p_key: `demo:${ip}`, p_window_seconds: 3600, p_max: 5 });
        if (!allowed) return json({ ok: false, error: 'rate_limited' }, 429);
        const name = str(body.name, 120);
        const phone = str(body.phone, 30);
        if (!name || !phone) return json({ ok: false, error: 'bad_request' }, 400);
        const { error } = await db.from('demo_requests').insert({ name, phone, business_name: str(body.business_name, 120) });
        return error ? rpcFail('demo_request', error.code) : json({ ok: true });
      }
      case 'POST /public/report': {
        const { data: biz } = await db.from('businesses').select('id').eq('slug', str(body.slug, 40)).maybeSingle();
        if (!biz) return json({ ok: false, error: 'not_found' }, 404);
        await db.from('content_reports').insert({ business_id: biz.id, reason: str(body.reason, 500) });
        return json({ ok: true });
      }
      case 'POST /feedback': {
        const rating = Number(body.rating);
        if (!Number.isInteger(rating) || rating < 1 || rating > 5) return json({ ok: false, error: 'bad_request' }, 400);
        const text = str(body.text, 2000);
        const { data, error } = await db.rpc('submit_feedback', {
          p_slug: str(body.slug, 40), p_device: str(body.device, 64) || 'unknown', p_rating: rating,
          p_text: text, p_contact: str(body.contact, 200), p_tag_code: str(body.tag, 40) || null,
        });
        if (error) return rpcFail('submit_feedback', error.code);
        if (data.ok && data.telegram_chat_id) {
          await notifyTelegram(data.telegram_chat_id, `${data.business_name}: yangi fikr, baho ${rating}/5\n${text}`);
        }
        return json({ ok: data.ok, error: data.error });
      }
    }
    if (path[0] === 'me' || path[0] === 'guest') return await guestRoute(db, req, route, url, body);
    if (['staff', 'biz', 'ai', 'admin'].includes(path[0])) return await staffRoute(db, req, route, body);
    return json({ ok: false, error: 'not_found' }, 404);
  } catch (err) {
    console.error('unhandled', route, err instanceof Error ? err.message : 'unknown');
    return json({ ok: false, error: 'server_error' }, 500);
  }
});
