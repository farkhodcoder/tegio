import type { I18nMap, PublicCategory, PublicMenuItem, PublicPage } from '#lib/types.ts';

type Four = [string, string, string, string];

const LOCALES = ['uz', 'uz-Cyrl', 'ru', 'en'] as const;

function i18n(fields: Record<string, Four>): I18nMap {
  const map: I18nMap = {};
  for (const [field, values] of Object.entries(fields)) {
    LOCALES.forEach((locale, index) => (map[`${field}:${locale}`] = values[index]));
  }
  return map;
}

let id = 0;

function item(price: number, tags: string[], name: Four, description: Four, portion: Four, available = true): PublicMenuItem {
  return { id: `i${++id}`, price_uzs: price, photo_url: null, tags, available, i18n: i18n({ name, description, portion }) };
}

function category(name: Four, items: PublicMenuItem[]): PublicCategory {
  return { id: `c${++id}`, i18n: i18n({ name }), items };
}

const plate: Four = ['1 porsiya', '1 порция', '1 порция', '1 serving'];

const anor: PublicPage = {
  status: 'active',
  name: 'Anor choyxonasi',
  slug: 'anor',
  brand: { primary: '#1D3FA8', tagline: 'Toshkentning issiq noni va achchiq choyi' },
  show_branding: true,
  tag: null,
  location: {
    id: 'loc-1',
    name: 'Chilonzor',
    address: 'Toshkent, Chilonzor 9-kvartal',
    timezone: 'Asia/Tashkent',
    google_review_url: 'https://www.google.com/maps',
    wifi_ssid: 'Anor-Mehmon',
    wifi_password: 'anor-choy-2026'
  },
  items: [
    { kind: 'menu', label: null, url: null },
    { kind: 'wifi', label: null, url: null },
    { kind: 'loyalty', label: null, url: null },
    { kind: 'feedback', label: null, url: null },
    { kind: 'instagram', label: null, url: 'https://instagram.com' },
    { kind: 'telegram', label: null, url: 'https://t.me' },
    { kind: '2gis', label: null, url: 'https://2gis.uz' },
    { kind: 'yandex', label: null, url: 'https://yandex.uz/maps' }
  ],
  program: {
    card: {},
    tiers: [
      { stamps_required: 5, title: 'Somsa' },
      { stamps_required: 10, title: 'Bir choynak choy' }
    ]
  },
  menus: [
    {
      id: 'm-main',
      name: 'Taomlar',
      i18n: i18n({ name: ['Taomlar', 'Таомлар', 'Блюда', 'Food'] }),
      schedule: null,
      categories: [
        category(['Quyuq taomlar', 'Қуюқ таомлар', 'Горячие блюда', 'Main dishes'], [
          item(48000, ['halal'], ['Toshkent oshi', 'Тошкент оши', 'Ташкентский плов', 'Tashkent plov'],
            ['Devzira guruch, qoʻy goʻshti, sariq sabzi', 'Девзира гуруч, қўй гўшти, сариқ сабзи', 'Рис девзира, баранина, жёлтая морковь', 'Devzira rice, lamb, yellow carrot'], plate),
          item(36000, ['halal', 'allergen:gluten', 'spicy'], ['Qovurma lagʻmon', 'Қовурма лағмон', 'Жареный лагман', 'Fried lagman'],
            ['Qoʻlda choʻzilgan xamir, mol goʻshti, qalampir', 'Қўлда чўзилган хамир, мол гўшти, қалампир', 'Тянутая вручную лапша, говядина, перец', 'Hand-pulled noodles, beef, chili'], plate),
          item(42000, ['halal'], ['Qozon kabob', 'Қозон кабоб', 'Казан-кебаб', 'Kazan kebab'],
            ['Kartoshka va qoʻy goʻshti, qozonda', 'Картошка ва қўй гўшти, қозонда', 'Картофель и баранина в казане', 'Potatoes and lamb cooked in a kazan'], plate, false)
        ]),
        category(['Somsa va non', 'Сомса ва нон', 'Самса и хлеб', 'Somsa and bread'], [
          item(12000, ['halal', 'allergen:gluten'], ['Tandir somsa', 'Тандир сомса', 'Тандырная самса', 'Tandoor somsa'],
            ['Qoʻy goʻshti va piyoz', 'Қўй гўшти ва пиёз', 'Баранина и лук', 'Lamb and onion'], ['1 dona', '1 дона', '1 штука', '1 piece']),
          item(14000, ['vegetarian', 'allergen:gluten'], ['Qovoqli somsa', 'Қовоқли сомса', 'Самса с тыквой', 'Pumpkin somsa'],
            ['Qovoq va ziravorlar', 'Қовоқ ва зираворлар', 'Тыква и специи', 'Pumpkin and spices'], ['1 dona', '1 дона', '1 штука', '1 piece']),
          item(8000, ['vegetarian', 'allergen:gluten'], ['Patir non', 'Патир нон', 'Лепёшка патыр', 'Patir flatbread'],
            ['Tandirdan yangi', 'Тандирдан янги', 'Прямо из тандыра', 'Fresh from the tandoor'], ['1 dona', '1 дона', '1 штука', '1 piece'])
        ])
      ]
    },
    {
      id: 'm-breakfast',
      name: 'Nonushta',
      i18n: i18n({ name: ['Nonushta', 'Нонушта', 'Завтрак', 'Breakfast'] }),
      schedule: { from: '07:00', to: '11:00' },
      categories: [
        category(['Ertalabki taomlar', 'Эрталабки таомлар', 'Завтраки', 'Breakfast'], [
          item(22000, ['vegetarian', 'allergen:dairy', 'allergen:gluten'], ['Qaymoq va non', 'Қаймоқ ва нон', 'Каймак с лепёшкой', 'Clotted cream and bread'],
            ['Asal bilan', 'Асал билан', 'С мёдом', 'With honey'], plate),
          item(26000, ['halal', 'allergen:dairy'], ['Tuxumli qovurdoq', 'Тухумли қовурдоқ', 'Кавурдак с яйцом', 'Kovurdak with eggs'],
            ['Goʻsht, tuxum, koʻkat', 'Гўшт, тухум, кўкат', 'Мясо, яйца, зелень', 'Meat, eggs, herbs'], plate)
        ])
      ]
    },
    {
      id: 'm-drinks',
      name: 'Ichimliklar',
      i18n: i18n({ name: ['Ichimliklar', 'Ичимликлар', 'Напитки', 'Drinks'] }),
      schedule: null,
      categories: [
        category(['Choy', 'Чой', 'Чай', 'Tea'], [
          item(10000, ['vegetarian'], ['Koʻk choy', 'Кўк чой', 'Зелёный чай', 'Green tea'],
            ['Choynakda', 'Чойнакда', 'В чайнике', 'By the pot'], ['0,7 l', '0,7 л', '0,7 л', '0.7 l']),
          item(15000, ['vegetarian', 'allergen:nuts'], ['Yongʻoqli sheker choy', 'Ёнғоқли шекер чой', 'Чай с орехами', 'Walnut sugar tea'],
            ['Yongʻoq va navvot bilan', 'Ёнғоқ ва навбот билан', 'С орехами и наватом', 'With walnuts and rock sugar'], ['0,7 l', '0,7 л', '0,7 л', '0.7 l'])
        ])
      ]
    }
  ]
};

const yopiq: PublicPage = { status: 'payment_stopped', name: 'Eski bekat kafesi', slug: 'yopiq' };

export const DEMO_PAGES: Record<string, PublicPage> = { anor, yopiq };

// Namuna kod: S{stol raqami}. Haqiqiy kodlar tags jadvalidan keladi.
export function demoTag(code: string): { id: string; table_label: string } | null {
  const table = /^S([1-9]\d{0,2})$/.exec(code)?.[1];
  return table ? { id: `tag-${table}`, table_label: table } : null;
}
