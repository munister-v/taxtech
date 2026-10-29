# Фото для лендингу

Лендинг (`web/src/BankLanding.tsx`) побудований на справжніх фотографіях: Рим, Колізей, Пантеон, Форум, плюс кадр
оплати карткою і зйомка Saint Agnes з магазину. Векторних малюнків немає. Картки показано в CSS, поверх кадрів
лежать темні градієнти, тож текст читається.

Фото лежать у `web/public/landing/` (WebP, 2400 px по довгій стороні) і підключені як `background-image`.

| Файл | Де стоїть | Джерело і ліцензія |
|---|---|---|
| `rome-colosseum-night.webp` | перший екран | [John Samuel](https://commons.wikimedia.org/wiki/File:Colosseum_at_night_01.jpg), CC BY-SA 4.0 |
| `pay-tap.webp` | сцена «Дотик. Оплачено.» | [SumUp / Unsplash](https://unsplash.com/photos/payment-is-being-made-with-a-credit-card-AAYpF9Vx7Ek), ліцензія Unsplash |
| `rome-forum-sunset.webp` | депозит | [Sonse](https://commons.wikimedia.org/wiki/File:Sunset_over_Roman_Forum_(45485877135).jpg), CC BY 2.0 |
| `rome-pantheon-night.webp` | безпека | [DeveshT](https://commons.wikimedia.org/wiki/File:Pantheon_-_Rome_at_night.jpg), CC0 |
| `rome-colosseum-day.webp` | фінальний заклик | [Diliff](https://commons.wikimedia.org/wiki/File:Colosseum_in_Rome,_Italy_-_April_2007.jpg), CC BY-SA 2.5 |

Сцена Saint Agnes бере `/shop/hero-autumn.webp` з магазину, а товари підтягує з `/api/marketplace/catalog`.

Подяки авторам виведено в підвалі лендингу (`.bl-credits`). Якщо міняєте кадр, оновіть і підпис, і цю таблицю.

## Як замінити кадр

Беріть оригінал з Wikimedia Commons (API з `iiurlwidth=2400`) або з Unsplash. Перевіряйте ліцензію: для CC BY і
CC BY-SA потрібна атрибуція в підвалі. Потім:

```bash
cwebp -q 82 -resize 2400 0 original.jpg -o web/public/landing/<name>.webp
cd web && npm run build
```

Далі викладається лише `server/frontend/` (див. `server/README.md`, розділ про розгортання). Перший екран тримайте
до ~400 КБ.
