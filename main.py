#!/usr/bin/env python3
"""
ФССП Тест-бот - Production-Ready версия
"""

import asyncio
import logging
from pathlib import Path
from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from dotenv import load_dotenv

# Загрузка переменных окружения
load_dotenv()

# Импорты
from config.settings import BOT_TOKEN, DB_PATH
from database.db import Database
from library.middlewares import AntiSpamMiddleware, ErrorHandlerMiddleware

# Импорт handlers
from handlers import start, registration, testing

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('bot.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)


async def main():
    """Главная функция"""
    logger.info("🚀 Запуск ФССП Тест-бота...")
    
    # Проверка токена
    if not BOT_TOKEN:
        logger.error("❌ BOT_TOKEN не установлен! Создайте файл .env с токеном.")
        return
    
    # Инициализация бота
    bot = Bot(
        token=BOT_TOKEN,
        default=DefaultBotProperties(parse_mode=ParseMode.HTML)
    )
    
    dp = Dispatcher()
    
    # Подключение middleware
    dp.update.middleware(AntiSpamMiddleware())
    dp.update.middleware(ErrorHandlerMiddleware())
    
    # Регистрация роутеров
    dp.include_router(start.router)
    dp.include_router(registration.router)
    dp.include_router(testing.router)
    
    # Инициализация базы данных
    db = Database(DB_PATH)
    await db.init_db()
    logger.info("✅ База данных инициализирована")
    
    # Запуск бота
    try:
        logger.info("✅ Бот запущен и готов к работе!")
        await dp.start_polling(bot)
    except Exception as e:
        logger.error(f"❌ Ошибка при запуске бота: {e}")
    finally:
        await bot.session.close()
        logger.info("🛑 Бот остановлен")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("⏹ Бот остановлен пользователем")
