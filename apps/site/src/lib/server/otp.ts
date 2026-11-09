import type { Cookies } from '@sveltejs/kit';
import { normalizeUzPhone } from '#lib/phone.ts';
import { backend, SESSION_COOKIE } from './backend';

const SESSION_MAX_AGE = 60 * 60 * 24 * 90;

export async function sendOtpAction(request: Request, ip: string) {
  const form = await request.formData();
  const phone = normalizeUzPhone(String(form.get('phone') ?? ''));
  if (!phone) return { otpError: 'phone' };
  const sent = await backend.sendOtp(phone, ip);
  if (!sent.ok) return { otpError: sent.error === 'rate_limited' ? 'rate' : 'sms' };
  return { phone, devCode: sent.devCode };
}

export async function verifyOtpAction(request: Request, cookies: Cookies) {
  const form = await request.formData();
  const phone = normalizeUzPhone(String(form.get('phone') ?? ''));
  const code = String(form.get('code') ?? '').trim();
  const session = phone ? await backend.verifyOtp(phone, code) : null;
  if (!session) return { phone: phone ?? undefined, otpError: 'code' };
  cookies.set(SESSION_COOKIE, session, { path: '/', httpOnly: true, sameSite: 'lax', maxAge: SESSION_MAX_AGE });
  return { verified: true };
}
