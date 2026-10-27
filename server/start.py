"""Точка входу для запуску dev-сервера Kopiyka (пісочниця на віртуальних грошах)."""
from backend.app import app
from backend.config import DEBUG, HOST, PORT

if __name__ == '__main__':
    # Порт 5050 за замовчуванням: на macOS порт 5000 часто зайнятий AirPlay
    app.run(debug=DEBUG, host=HOST, port=PORT)
