"""Cron: повторно відправити в магазин замовлення, що не дійшли. Запуск з каталогу server/."""
from backend.database import get_connection
from backend.services import shop_sync

with get_connection() as conn:
    print('synced', shop_sync.sync_pending(conn))
