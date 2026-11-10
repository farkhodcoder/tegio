# Domenga ulash

Backend Supabase'da ishlayapti (loyiha `zfgeeblonoxqxcdndshm`, `ap-south-1`). Sayt, restoran tizimi va admin panel Vercel'ga alohida-alohida joylanadi. Domen hali tanlanmagan, quyida `tegio.uz` o'rniga haqiqiy domeningizni yozing.

| Manzil | Ilova |
| --- | --- |
| `tegio.uz` | Mehmon sayti (`apps/site`) |
| `biz.tegio.uz` | Restoran tizimi (`apps/biz`) |
| `admin.tegio.uz` | Admin panel (`apps/admin`) |

## 0. Sinov havolalari (domen ulanguncha)

| Manzil | Ilova | Rejim |
| --- | --- | --- |
| https://tegio-site.vercel.app | Mehmon sayti | Demo (`TEGIO_DEMO=1`): xotiradagi namuna kafe, SMS kodi ekranda |
| https://tegio-biz.vercel.app | Restoran tizimi | Jonli Supabase, kirish uchun SMS kaliti kerak |
| https://tegio-admin.vercel.app | Admin panel | Jonli Supabase, birinchi admin 6-bo'limdagidek |

Sayt Vercel'ning o'zida build qilinadi (Root Directory `apps/site`): Windows'da qurilgan `.vercel/output` Linux'da ishlamaydi. Yangilash uchun repozitoriy ildizidan `npx vercel deploy --prod`. Haqiqiy backend'ga o'tishda `TEGIO_DEMO` ni o'chirib, `TEGIO_API_URL` qo'ying.

## 1. Edge Function sirlari

Supabase Dashboard: Project Settings, Edge Functions, Secrets. Kalit qo'shilmaguncha tegishli funksiya xato qaytarmaydi, foydalanuvchiga "ulanmagan" deb aytadi.

| Sir | Nima uchun |
| --- | --- |
| `ESKIZ_EMAIL`, `ESKIZ_PASSWORD`, `ESKIZ_FROM` | SMS kod. Busiz hech kim telefon orqali kira olmaydi |
| `SMS_TEMPLATE` | Ixtiyoriy. Eskiz'da tasdiqlangan matn, `{code}` bilan |
| `CLICK_SERVICE_ID`, `CLICK_MERCHANT_ID`, `CLICK_SECRET_KEY` | Click to'lovi |
| `PAYME_MERCHANT_ID`, `PAYME_KEY` | Payme to'lovi |
| `TELEGRAM_BOT_TOKEN` | Yangi fikr haqida Telegram xabari |
| `ANTHROPIC_API_KEY` | Menyuni rasmdan o'qish va tarjima |

To'lov tizimlari kabinetida webhook manzillari:

- Click: `https://zfgeeblonoxqxcdndshm.supabase.co/functions/v1/api/webhooks/click`
- Payme: `https://zfgeeblonoxqxcdndshm.supabase.co/functions/v1/api/webhooks/payme`

`OTP_DEV_MODE=true` kodni javobda qaytaradi. U faqat Eskiz ulanmagan paytdagi qisqa sinov uchun; har qanday telefon raqamiga kirish ochiladi, shuning uchun sinovdan keyin darhol o'chiring.

## 2. Sayt

Vercel'da yangi loyiha, shu repozitoriydan:

- Root Directory: `apps/site`
- Framework: SvelteKit (avtomatik aniqlanadi)
- Environment Variables:

| O'zgaruvchi | Qiymat |
| --- | --- |
| `TEGIO_API_URL` | `https://zfgeeblonoxqxcdndshm.supabase.co/functions/v1/api` |
| `TEGIO_PUBLIC_URL` | `https://tegio.uz` |
| `BIZ_URL` | `https://biz.tegio.uz` |

`TEGIO_API_URL` qo'yilmasa, Vercel'dagi build atayin to'xtaydi: demo ma'lumot jonli saytga chiqmasligi kerak.

## 3. Restoran tizimi va admin panel

`TEGIO_PUBLIC_URL` Flutter'ga build vaqtida yoziladi va stol QR yorliqlari shu manzilga olib boradi. Yorliqlarni chop etishdan oldin haqiqiy domen bilan build qiling.

```bash
cd apps/biz
```

```bash
flutter build web --release --dart-define=TEGIO_PUBLIC_URL=https://tegio.uz
```

```bash
npx vercel deploy build/web --prod
```

Admin panel uchun xuddi shu uch buyruq, `apps/admin` papkasida. Har biri alohida Vercel loyihasi bo'ladi.

## 4. DNS

Har bir Vercel loyihasida Settings, Domains orqali domenni qo'shing. Vercel ko'rsatgan yozuvlar ustun turadi, odatda:

| Yozuv | Nom | Qiymat |
| --- | --- | --- |
| A | `@` | `76.76.21.21` |
| CNAME | `www` | `cname.vercel-dns.com` |
| CNAME | `biz` | `cname.vercel-dns.com` |
| CNAME | `admin` | `cname.vercel-dns.com` |

SSL sertifikatini Vercel o'zi beradi.

## 5. Supabase Auth

Dashboard: Authentication.

- URL Configuration: Site URL = `https://admin.tegio.uz`. Redirect URLs ga `https://admin.tegio.uz/**` va `https://biz.tegio.uz/**`.
- Sign In / Providers: "Allow new users to sign up" ni o'chiring. Telefon akkauntlarini server o'zi yaratadi, adminlar taklif bilan kiradi.
- Multi-Factor: TOTP yoqilgan bo'lsin.

## 5a. Restoran tizimiga Google orqali kirish

1. Google Cloud Console, APIs & Services, Credentials: "OAuth client ID", turi Web application.
   Authorized redirect URI: `https://zfgeeblonoxqxcdndshm.supabase.co/auth/v1/callback`.
2. Supabase Dashboard, Authentication, Sign In / Providers, Google: yoqing, Client ID va Client Secret'ni qo'ying.
3. Authentication, URL Configuration, Redirect URLs: `https://tegio-biz.vercel.app/**` (domen ulanganda `https://biz.tegio.uz/**`).
4. Google akkaunti birinchi marta kirganda hisob yaratiladi, shuning uchun "Allow new users to sign up" yoqilgan bo'lishi kerak.
   Xavfsiz: biznesni faqat tasdiqlangan telefon yoki Google akkaunti ochadi (`private.can_open_business`), admin bo'lish uchun esa `admin_users` dagi taklif va TOTP kerak.

Google bilan kirgan xodimga telefon bo'yicha yuborilgan taklif bog'lanmaydi: xodimlar telefon orqali kiradi.

## 6. Birinchi super admin

1. SQL Editor'da taklif yozing (emailni o'zingiznikiga almashtiring). Hisob shu email bilan ochilganda u avtomatik bog'lanadi:

```sql
insert into public.admin_users (email, role, status) values ('siz@misol.uz', 'super_admin', 'invited');
```

2. Dashboard, Authentication, Users, Add user: shu email va kuchli parol, "Auto Confirm User" belgilangan.

Eski usul (hisob allaqachon bor bo'lsa):

```sql
insert into public.admin_users (user_id, email, role, status)
select id, email, 'super_admin', 'invited' from auth.users where email = 'siz@misol.uz';
```

3. `admin.tegio.uz` ga kiring, TOTP'ni ulang. Birinchi muvaffaqiyatli kirishda holat `active` bo'ladi. Keyingi adminlar panelning Xavfsizlik bo'limidan taklif qilinadi.

## 7. Tekshiruv

- `https://tegio.uz` da tariflar ko'rinadi.
- `https://tegio.uz/me` da o'z raqamingizga SMS keladi va kirasiz.
- `biz.tegio.uz` da biznes yarating, sahifani e'lon qiling, `tegio.uz/<slug>` ochiladi.
- Stol QR'ini telefonda skan qiling, karta oching, kassir bo'limida shtamp qo'ying.
- Click yoki Payme bilan eng kichik tarifni to'lang, tarif yoqilganini tekshiring.
