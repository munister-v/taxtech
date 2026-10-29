# Фото для лендингу

Лендинг (`web/src/BankLanding.tsx`) зроблено в мові Saint Agnes: кремовий папір, Jost великими літерами,
фото на всю ширину з темною вуаллю. Кожне місце для фото вже чекає на файл: покладіть його в
`web/public/landing/` під потрібним ім’ям, зберіть і викладіть фронтенд. Доки файлу немає, показується фото
з картки Roma.

Загальний стиль для всіх кадрів: тепле природне світло, кремово-пісочна й чорна гама з мідними акцентами
(як `#f7f5f0`, `#171714`, `#e8b98a`), спокійні дорослі люди 28–45 років, одяг у дусі Saint Agnes (верблюже
пальто, твід, кашемір, чорний пуховик), без логотипів реальних банків і брендів на екранах, без тексту в кадрі.
На телефоні в кадрі допускається лише розмитий світлий екран.

| Файл | Розмір | Де стоїть | Важливо для композиції |
|---|---|---|---|
| `hero.webp` | 2400×1350 (16:9) | перший екран, на всю ширину | людина праворуч від центру: ліва третина темна й спокійна, там текст; на телефоні кадр обрізається до вертикалі по центру-праворуч |
| `save.webp` | 1600×1000 (16:10) | плитка «Депозити» | низ кадру темніший, там заголовок і кнопка |
| `borrow.webp` | 1600×1000 (16:10) | плитка «Кредит» | так само, низ темніший |
| `security.webp` | 2400×1000 (12:5) | банер «Захищено на кожному кроці» | ліва половина темна, людина праворуч |

## Промпти

**hero.webp**
> Editorial fashion photograph, a woman in her thirties in a camel wool coat walking down a quiet Roman street at
> golden hour, holding a phone with a blank softly glowing screen, travertine walls and arches behind her, subject on
> the right third, the left third falls into deep warm shadow, cream, sand and black palette with copper highlights,
> 50mm, shallow depth of field, natural light, no text, no logos, 16:9

**save.webp**
> Editorial photograph, a man in a cream cashmere sweater sitting by a tall window in a calm stone-walled apartment
> in Rome, morning light, a cup of coffee and a closed notebook on a travertine table, relaxed and unhurried,
> warm sand and cream palette, darker lower third, no text, no logos, 16:10

**borrow.webp**
> Editorial photograph, a young couple in tweed and black wool coats standing in the doorway of an empty light-filled
> apartment with arched windows, keys in hand, warm natural light, cream and charcoal palette, darker lower third,
> no text, no logos, 16:10

**security.webp**
> Editorial photograph at night, a woman in a black down jacket under a Roman stone arch, face lit softly by a phone
> held close, the rest of the frame in deep shadow, subject on the right, the left half almost black, warm amber
> street light, cinematic, no text, no logos, 12:5

## Як додати

```bash
cp ~/Downloads/hero.webp web/public/landing/hero.webp   # і так для save, borrow, security
cd web && npm run build
```

Далі викладається лише `server/frontend/` (див. `server/README.md`, розділ про розгортання). Фото краще
стискати у WebP з якістю 80–85: перший екран має важити до ~400 КБ.
