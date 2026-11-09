# TEGIO

Restoran va kafelar uchun web platforma: mehmon QR yoki NFC yorliqni skan qiladi va hech narsa o'rnatmasdan menyu, Wi-Fi, bonus kartasi va fikr bildirishni ochadi.

Talablar: `TEGIO — Texnik topshiriq (TTZ)`. Qaysi talab qay holatda ekani: [docs/holat.md](docs/holat.md).

## Tuzilma

| Papka | Vazifa | Texnologiya |
| --- | --- | --- |
| `apps/site` | Mehmon sayti: bosh sayt, kafe sahifasi, karta, `/me` | SvelteKit |
| `apps/biz` | Restoran tizimi va kassir | Flutter Web |
| `apps/admin` | Admin panel | Flutter Web |
| `packages/tegio_core` | Flutter ilovalari uchun umumiy kod | Dart |
| `supabase/migrations` | Sxema, RLS, biznes funksiyalar | Postgres |
| `supabase/functions` | Edge Functions | Deno |
| `supabase/tests` | Baza va token sinovlari, Docker kerak emas | PGlite |
| `config/brand.json` | Logotip va ranglar, yagona manba | |

Brendni o'zgartirish: `config/brand.json` ni tahrirlang, keyin Flutter uchun konstantalarni yangilang:

```bash
pnpm sync:brand
```

## Ishga tushirish

```bash
pnpm install
```

```bash
pnpm dev
```

Sayt `http://localhost:5173` da ochiladi. Supabase ulanmagan, shuning uchun u xotiradagi demo ma'lumot bilan ishlaydi (`apps/site/src/lib/server/demo.ts`). Namuna sahifalar: `/anor?t=S7`, stol QR yorliqlari `/anor/yorliq` va to'lovi to'xtagan biznes `/yopiq`. SMS kod demo rejimda ekranda ko'rinadi.

Yorliqni telefonda sinash uchun sayt bir Wi-Fi tarmog'ida ochilishi kerak. Build qiling, keyin ishga tushiring va `/anor/yorliq` ni kompyuterning tarmoq manzili orqali oching (QR shu manzilni oladi):

```bash
pnpm build
```

```bash
pnpm --filter @tegio/site preview:lan
```

Domen ulanganda QR manzilini `TEGIO_PUBLIC_URL` belgilaydi.

Flutter ilovalari:

```bash
flutter run -d chrome -t apps/biz/lib/main.dart
```

## Sinovlar

```bash
pnpm test:db
```

```bash
pnpm --filter @tegio/site test
```

```bash
flutter test packages/tegio_core
```

Sinov nomlarida TTZ talab raqami turadi (masalan `B-29`), shuning uchun talabdan sinovga qidirib o'tish mumkin.
