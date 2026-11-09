# Web MVP holati

Oxirgi yangilanish: 2026-11-10.

Backend Supabase'da ishlayapti (loyiha `zfgeeblonoxqxcdndshm`). Sayt, restoran tizimi va admin panel unga ulangan.

**Yozilgan**: kod bor, avtomatik sinovlar yoki build o'tgan. **Kalit kerak**: kod bor, lekin tashqi xizmat kaliti qo'yilmaguncha ishlamaydi va sinab ko'rilmagan. **Qisman**: talabning bir qismi bor. **Yo'q**: qurilmagan.

## Foydalanuvchilar sayti

| Talablar | Holat | Izoh |
| --- | --- | --- |
| G-01 – G-08, M-01 – M-07, W-01, W-02 | Yozilgan | W-02 haqiqiy telefonda hali sinalmagan |
| L-01 – L-05 | Yozilgan | Kirish SMS'ga bog'liq: Eskiz kaliti kerak |
| L-06, L-07 | Yo'q | Apple Pass Type ID sertifikati kerak |
| F-01 – F-06 | Yozilgan | Telegram xabari uchun bot tokeni kerak |
| U-01 – U-06 | Yozilgan | Kirish SMS'ga bog'liq |
| S-01 – S-04 | Yozilgan | Shartlar va maxfiylik qoralama, yurist tasdiqlaydi |
| S-05 | Qisman | Sarlavha, Open Graph, sitemap bor; tillar uchun alohida URL yo'q |
| S-06 | Yozilgan | Admin paneldagi kontent saytdagi matnlar ustidan yoziladi |

## Restoran tizimi (`apps/biz`)

| Talablar | Holat | Izoh |
| --- | --- | --- |
| Kirish, biznes yaratish, sahifa sozlash, menyu, sodiqlik, kassir, fikrlar, mijozlar, jamoa | Yozilgan | Build o'tgan. Haqiqiy akkaunt bilan ochib ko'rilmagan |
| B-14, B-15 (AI menyu va tarjima) | Kalit kerak | `ANTHROPIC_API_KEY`. Natija doim qoralama, egasi tasdiqlaydi |
| To'lov (Click, Payme) | Kalit kerak | Webhook'lar yozilgan, merchant hisobi bilan sinalmagan |
| B-08 | Yozilgan | Biz'da. Saytdagi `/{kafe}/yorliq` faqat demo rejimda qoldi |
| B-37 | Qisman | Excel ochadigan CSV, `.xlsx` emas |
| Tarif cheklovlari (`modules_json`) | Yo'q | Tariflar saqlanadi, modullarga ruxsat tarif bo'yicha cheklanmaydi |

## Admin panel (`apps/admin`)

| Talablar | Holat | Izoh |
| --- | --- | --- |
| Boshqaruv, bizneslar, tariflar va to'lovlar, yorliqlar, yordam, kontent, xavfsizlik | Yozilgan | Email + TOTP, har bir RPC `aal2` ni tekshiradi. Build o'tgan, haqiqiy admin bilan ochib ko'rilmagan |
| P-04 (tizim holati ekrani) | Yo'q | |
| P-28 (sessiya muddati) | Qisman | Supabase tarifiga bog'liq |

## Nofunksional talablar

| Yo'nalish | Holat |
| --- | --- |
| Birinchi yuklash JS ≤ 100 KB | Oxirgi o'lchovda kafe sahifasi 43 KB gzip |
| Izolyatsiya (RLS) | Avtomatik sinovlar o'tgan |
| QR tokeni, 60 s, bir martalik | Sinovlar o'tgan |
| Wi-Fi paroli shifrlangan | Sinov o'tgan |
| Zaif internet (menyu keshi) | Tekshirilgan |
| Tillar | 4 til. Taom va kategoriyalar tarjima qilinadi; mukofot nomi va shior hali bir tilda |
| Restoran tizimi birinchi yuklash ≤ 5 s, LCP ≤ 2,0 s, 1000 skan yuklama, real qurilmalar | O'lchanmagan |

## Ma'lum cheklovlar

- SMS kaliti qo'yilmaguncha telefon orqali kirishning musbat yo'li jonli muhitda sinalmagan.
- Supabase maslahatlari: 13 ta INFO (faqat server o'qiydigan jadvallarda siyosat yo'q, ataylab) va 31 ta WARN (har biri rolni o'zi tekshiradigan RPC'lar). Unumdorlik bo'yicha: `guests` siyosatlarida `auth.uid()` har qatorda hisoblanadi, 31 ta tashqi kalitda indeks yo'q. Yuk oshganda ko'rib chiqiladi.
- Muddati o'tgan shtamplar keyingi shtamp qo'yilganda yonadi; kartada ko'rsatish uchun rejali vazifa kerak.
- Kassir roli uchun filial bo'yicha o'qish cheklovi yo'q: filialga biriktirilgan kassir o'z biznesining barcha jurnalini ko'radi.

## TTZ ochiq savollari

Domen va savdo belgisi, logotip va ranglar, telefon raqamlari saqlanish joyi (yurist, hozir `ap-south-1`), Google Wallet, birinchi shahar, yorliq ishlab chiqaruvchi, Telegram orqali tasdiqlash.

Hozirgi ranglar va namuna kafe vaqtincha: brend tayyor bo'lganda `config/brand.json` almashtiriladi.

Joylash qadamlari: [deploy.md](deploy.md).
