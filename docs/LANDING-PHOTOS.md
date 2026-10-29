# Фото для лендингу

Лендинг (`web/src/BankLanding.tsx`) темний, у дусі Apple: великий текст по центру, багато повітря. Карти
намальовано в CSS, тож фото потрібні лише для чотирьох повноекранних вставок. Кожна вставка вже чекає на файл:
покладіть його в `web/public/landing/` під потрібним ім’ям, зберіть і викладіть фронтенд. Доки файлу немає,
вставка лишається чистим темним полем.

Загальний стиль серії: темні, художні, кінематографічні кадри Рима та Італії. Глибокі тіні, мало світла,
теплі бурштинові й медові відблиски (`#c7a46f`), холодний синій «knight» (`#1c2740`) у тінях, легке плівкове
зерно, жодного тексту, логотипів і впізнаваних облич. Над кожним кадром лежить темний градієнт, а низ
перекриває текст, тож нижня третина кадру має бути спокійною й темною.

| Файл | Розмір | Де стоїть | Композиція |
|---|---|---|---|
| `hero.webp` | 2400×1600 | перший екран, за заголовком і карткою | центр кадру темний і рівний (там текст і картка), світло по краях |
| `rome.webp` | 2400×1350 | «Платіть одним поглядом» | текст унизу по центру; головний об’єкт у верхніх двох третинах |
| `night.webp` | 2400×1600 | «Безпека» | текст і три плитки по центру; кадр майже чорний, світло лише по краях |
| `coast.webp` | 2400×1600 | фінальний заклик «Ваша картка чекає» | текст по центру; широкий спокійний горизонт |

## Промпти

**hero.webp**
> Dark cinematic fine-art photograph of the Colosseum at blue hour, seen through a stone archway, deep shadows,
> only the upper arches catching warm amber light, the centre of the frame calm and nearly black, cold navy sky,
> subtle film grain, Roman travertine texture, no people, no text, 3:2

**rome.webp**
> Dark fine-art photograph of a narrow Roman street at night after rain, cobblestones reflecting a single warm
> street lamp, an ivy-covered ochre facade fading into shadow, a lone figure seen from behind far away,
> chiaroscuro, honey and deep blue tones, film grain, lower third dark and empty, no text, 16:9

**night.webp**
> Dark moody photograph of a classical marble statue in a Roman museum at night, lit by a single narrow beam of
> warm light from the side, the rest of the frame falling into black, velvet shadows, museum stillness,
> fine-art, film grain, no text, 3:2

**coast.webp**
> Dark cinematic photograph of the Amalfi coast at dusk from a high terrace, the last honey-coloured light on the
> cliffs, the sea turning deep navy, tiny warm lights of a village, a quiet empty horizon across the middle of the
> frame, film grain, no people, no text, 3:2

## Як додати

```bash
cp ~/Downloads/hero.webp web/public/landing/hero.webp   # і так для rome, night, coast
cd web && npm run build
```

Далі викладається лише `server/frontend/` (див. `server/README.md`, розділ про розгортання). WebP з якістю
80–85, перший екран до ~400 КБ.
