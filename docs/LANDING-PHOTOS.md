# Фото для лендингу

Лендинг (`web/src/BankLanding.tsx`) стоїть на справжніх фотографіях Рима з ефектами поверх. Векторних малюнків немає.
Фото лежать у `web/public/landing/` (WebP, 2400 px по довгій стороні).

| Файл | Де стоїть | Джерело і ліцензія |
|---|---|---|
| `colosseum-dawn.webp` | перший екран | [Radek Kucharski](https://commons.wikimedia.org/wiki/File:Early_morning_Colosseo_-_Flickr_-_radkuch.13.jpg), CC BY 2.0 |
| `rome-forum-sunset.webp` | сцена «Один вечір у Римі», 19:10 | [Sonse](https://commons.wikimedia.org/wiki/File:Sunset_over_Roman_Forum_(45485877135).jpg), CC BY 2.0 |
| `rome-pantheon-night.webp` | сцена «Один вечір у Римі», 21:30 | [DeveshT](https://commons.wikimedia.org/wiki/File:Pantheon_-_Rome_at_night.jpg), CC0 |
| `rome-trevi-night.webp` | сцена «Один вечір у Римі», 23:40 | [miketnorton](https://commons.wikimedia.org/wiki/File:Trevi_Fountain_Long_Exposure.jpg), CC BY 2.0 |
| `pay-tap.webp` | сцена «Дотик. Оплачено.» | [SumUp / Unsplash](https://unsplash.com/photos/payment-is-being-made-with-a-credit-card-AAYpF9Vx7Ek), ліцензія Unsplash |
| `colosseum-sun.webp` | фінальний заклик | [Quentin Lowagie](https://commons.wikimedia.org/wiki/File:Sunset_trough_the_arches_of_the_Colosseum,_Rome.jpg), CC BY 4.0 |

Сцена Saint Agnes бере `/shop/hero-autumn.webp` з магазину, а товари підтягує з `/api/marketplace/catalog`.
Подяки авторам виведено в підвалі лендингу (`.bl-credits`). Якщо міняєте кадр, оновіть і підпис, і цю таблицю.

## Сцена «Один вечір у Римі»

Закріплена на екрані секція `.bl-rome` (440svh): скрол крутить годинник від 18:30 до 23:55, фото змінюють одне одного
(`DAY` у `BankLanding.tsx`), 3D-картка повертається, а під кожним кадром спливає платіж. Усе рахується в `frame()`
і лягає в CSS-змінні `--o`, `--z`, `--a`, `--ry`.

## Ефекти на фото (`web/src/FireScene.tsx`)

Перший екран і фінал малює `FireScene`: фото поводиться як `background-size: cover`, а поверх лежать
- світіння в освітлених арках, яке спалахує одне за одним і мерехтить;
- іскри, що здіймаються з арок (canvas, пауза поза екраном і за `prefers-reduced-motion`).

Координати арок лежать у `web/src/fireData.ts` (у відсотках від зображення), тож ефекти не з’їжджають із
архітектури за жодної обрізки. Нове фото потребує нових координат: зменшіть копію до 800 px, виділіть пікселі арок
(теплі: R>215, 120<G<215, B<120, R−B>110; сонячні: R, G, B>235) і знайдіть зв’язні області.
Центр і розмір кожної області йдуть у `fireData.ts`.

## Як замінити кадр

Беріть оригінал з Wikimedia Commons (API з `iiurlwidth=2400`) або з Unsplash. Для CC BY потрібна атрибуція
в підвалі. Потім:

```bash
cwebp -q 80 -resize 2400 0 original.jpg -o web/public/landing/<name>.webp
cd web && npm run build
```

Далі викладається лише `server/frontend/` (див. `server/README.md`, розділ про розгортання).
