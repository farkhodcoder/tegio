# Web MVP holati

Oxirgi yangilanish: 2026-11-09.

**Tayyor**: kod yozilgan va sinovdan o'tgan. **Demo**: sayt interfeysi ishlaydi, lekin ma'lumot xotirada, Supabase'ga ulanmagan. **Sxema**: baza qismi tayyor, interfeysi yo'q. **Yo'q**: hali boshlanmagan.

## Foydalanuvchilar sayti

| Talablar | Holat | Izoh |
| --- | --- | --- |
| G-01 – G-06, G-08 | Demo | Skan yozuvi demo'da faqat logga chiqadi |
| G-07 | Demo | Baza qoidasi sinovdan o'tgan |
| M-01 – M-07 | Demo | Filtr, qidiruv va jadval mantig'i sinovdan o'tgan |
| W-01 | Demo | |
| W-02 | Demo | Yorliqda alohida `WIFI:` QR. Haqiqiy telefonda hali sinalmagan |
| L-01 – L-05 | Demo | L-05 hozir 4 soniyalik so'rov bilan; Realtime ulanganda almashtiriladi |
| L-06, L-07 | Yo'q | Apple Pass Type ID sertifikati kerak |
| F-01 – F-06 | Demo | |
| U-01 – U-06 | Demo | Baza funksiyalari sinovdan o'tgan |
| S-01 – S-04 | Demo | Shartlar va maxfiylik qoralama, yurist tasdiqlaydi |
| S-05 | Qisman | Sarlavha, Open Graph, sitemap bor; tillar uchun alohida URL yo'q |
| S-06 | Yo'q | Admin panel bilan birga |

## Restoran tizimi (`apps/biz`)

Faqat qobiq: navigatsiya va bo'limlar ro'yxati. Bo'limlarning o'zi qurilmagan.

| Talablar | Holat | Izoh |
| --- | --- | --- |
| B-17 – B-19, B-24 – B-26, B-28, B-29 | Sxema | `apply_stamp`, `redeem_reward`, `find_member_by_phone`; Edge Function yozilgan |
| B-35, B-37 | Sxema | `business_customers` |
| B-39 | Sxema | Sinov muddati `create_business` da |
| B-08 | Demo | `/{kafe}/yorliq`: stol QR, A4 chop etish va PDF. Faqat demo rejimda ochiladi; restoran tizimida kirish bilan qurilishi kerak |
| Qolgani (B-01 – B-07, B-09 – B-16, B-20, B-23, B-27, B-30 – B-34, B-36, B-40, B-41) | Yo'q | |

## Admin panel (`apps/admin`)

Faqat qobiq. P-30 (o'zgartirilmaydigan jurnal) bazada tayyor, jadvallar sxemada bor, qolgani yo'q. 2FA va `/admin/*` hali yozilmagan.

## Nofunksional talablar

| Yo'nalish | Holat |
| --- | --- |
| Birinchi yuklash JS ≤ 100 KB | Kafe sahifasi 43 KB gzip |
| Izolyatsiya (RLS) | Avtomatik sinovlar o'tgan, 19 ta biznes jadvalida haqiqiy qatorlar bilan |
| QR tokeni, 60 s, bir martalik | Sinovlar o'tgan |
| Wi-Fi paroli shifrlangan | Sinov o'tgan |
| Zaif internet (menyu keshi) | Server o'chirilganda menyu keshdan ochilishi tekshirilgan |
| Tillar | 4 til. Taom va kategoriyalar tarjima qilinadi; mukofot nomi va shior hali bir tilda |
| Restoran tizimi birinchi yuklash ≤ 5 s | O'lchanmagan. Hozir `main.dart.js` 600 KB gzip |
| LCP ≤ 2,0 s, 1000 skan yuklama, real qurilmalar | O'lchanmagan |

## Ma'lum cheklovlar

- Sayt va Edge Functions hali bir-biriga ulanmagan: `apps/site/src/lib/server/backend.ts` demo'ga qaragan.
- Edge Functions real Supabase'da ishga tushirilmagan. Faqat `staff-stamp`, `staff-redeem` va `public` yozilgan; qolgan endpointlar yo'q.
- SMS provayderi tanlanmagan.
- Muddati o'tgan shtamplar keyingi shtamp qo'yilganda yonadi; kartada ko'rsatish uchun rejali vazifa kerak.
- Kassir roli uchun filial bo'yicha o'qish cheklovi yo'q: filialga biriktirilgan kassir o'z biznesining barcha jurnalini ko'radi.

## TTZ ochiq savollari

Domen va savdo belgisi, logotip va ranglar, telefon raqamlari saqlanish joyi (yurist), Google Wallet, birinchi shahar, yorliq ishlab chiqaruvchi, Telegram orqali tasdiqlash.

Hozirgi ranglar va namuna kafe vaqtincha: brend tayyor bo'lganda `config/brand.json` almashtiriladi.
