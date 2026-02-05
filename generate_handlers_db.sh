#!/bin/bash

echo "🚀 Генерация handlers и database..."

# database/db.py
cat > database/db.py << 'DBEOF'
"""Database"""
import aiosqlite
import logging
from pathlib import Path
from typing import List, Dict
from datetime import datetime

logger = logging.getLogger(__name__)

class Database:
    def __init__(self, db_path: Path):
        self.db_path = db_path
    
    async def init_db(self):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                CREATE TABLE IF NOT EXISTS users (
                    telegram_id INTEGER PRIMARY KEY,
                    full_name TEXT NOT NULL,
                    position TEXT,
                    department TEXT,
                    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            await db.execute('''
                CREATE TABLE IF NOT EXISTS tests (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    specialization TEXT NOT NULL,
                    difficulty_level TEXT NOT NULL,
                    total_questions INTEGER NOT NULL,
                    current_question INTEGER DEFAULT 0,
                    start_time TIMESTAMP NOT NULL,
                    end_time TIMESTAMP,
                    time_limit INTEGER NOT NULL,
                    status TEXT DEFAULT 'active',
                    FOREIGN KEY (user_id) REFERENCES users (telegram_id)
                )
            ''')
            
            await db.execute('''
                CREATE TABLE IF NOT EXISTS answers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    test_id INTEGER NOT NULL,
                    question_number INTEGER NOT NULL,
                    question_text TEXT NOT NULL,
                    user_answers TEXT,
                    correct_answers TEXT NOT NULL,
                    is_correct BOOLEAN NOT NULL,
                    FOREIGN KEY (test_id) REFERENCES tests (id)
                )
            ''')
            
            await db.execute('''
                CREATE TABLE IF NOT EXISTS results (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    test_id INTEGER NOT NULL,
                    correct_answers INTEGER NOT NULL,
                    total_questions INTEGER NOT NULL,
                    percentage REAL NOT NULL,
                    grade TEXT NOT NULL,
                    time_total INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (test_id) REFERENCES tests (id)
                )
            ''')
            
            await db.commit()
            logger.info("База данных инициализирована")
    
    async def save_user(self, telegram_id: int, full_name: str, position: str = None, department: str = None):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                INSERT OR REPLACE INTO users (telegram_id, full_name, position, department)
                VALUES (?, ?, ?, ?)
            ''', (telegram_id, full_name, position, department))
            await db.commit()
    
    async def create_test(self, user_id: int, specialization: str, difficulty: str, total_questions: int, time_limit: int) -> int:
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute('''
                INSERT INTO tests (user_id, specialization, difficulty_level, total_questions, start_time, time_limit)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (user_id, specialization, difficulty, total_questions, datetime.now().isoformat(), time_limit))
            await db.commit()
            return cursor.lastrowid
    
    async def save_answer(self, test_id: int, question_number: int, question_text: str, user_answers: str, correct_answers: str, is_correct: bool):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                INSERT INTO answers (test_id, question_number, question_text, user_answers, correct_answers, is_correct)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (test_id, question_number, question_text, user_answers, correct_answers, is_correct))
            await db.commit()
    
    async def complete_test(self, test_id: int):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''UPDATE tests SET status = 'completed', end_time = ? WHERE id = ?''', (datetime.now().isoformat(), test_id))
            await db.commit()
    
    async def save_result(self, test_id: int, correct: int, total: int, percentage: float, grade: str, time_total: int):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute('''
                INSERT INTO results (test_id, correct_answers, total_questions, percentage, grade, time_total)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (test_id, correct, total, percentage, grade, time_total))
            await db.commit()
    
    async def get_user_history(self, user_id: int) -> List[Dict]:
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute('''
                SELECT t.*, r.correct_answers, r.percentage, r.grade
                FROM tests t
                LEFT JOIN results r ON t.id = r.test_id
                WHERE t.user_id = ? AND t.status = 'completed'
                ORDER BY t.start_time DESC LIMIT 10
            ''', (user_id,)) as cursor:
                rows = await cursor.fetchall()
                return [dict(row) for row in rows]
DBEOF

echo "✅ database/db.py создан"

# handlers/__init__.py уже создан

# handlers/start.py
cat > handlers/start.py << 'STARTEOF'
"""Start handler"""
from aiogram import Router, F
from aiogram.filters import CommandStart
from aiogram.types import Message
from aiogram.fsm.context import FSMContext
from config.settings import MESSAGES
from library.keyboards import get_specializations_keyboard
from library.states import RegistrationStates

router = Router()

@router.message(CommandStart())
async def cmd_start(message: Message, state: FSMContext):
    await state.clear()
    await message.answer(
        MESSAGES['start'],
        reply_markup=get_specializations_keyboard(),
        parse_mode="HTML"
    )
    await state.set_state(RegistrationStates.choosing_specialization)
STARTEOF

echo "✅ handlers/start.py создан"

# handlers/registration.py
cat > handlers/registration.py << 'REGEOF'
"""Registration handlers"""
import json
from aiogram import Router, F
from aiogram.types import CallbackQuery, Message
from aiogram.fsm.context import FSMContext
from config.settings import MESSAGES, SPECIALIZATIONS, DATA_DIR
from library.keyboards import get_positions_keyboard, get_departments_keyboard, get_difficulty_keyboard
from library.states import RegistrationStates
from database.db import Database

router = Router()

# Загрузка данных
with open(DATA_DIR / 'positions.json', 'r', encoding='utf-8') as f:
    POSITIONS = json.load(f)

with open(DATA_DIR / 'departments.json', 'r', encoding='utf-8') as f:
    DEPARTMENTS = json.load(f)

@router.callback_query(F.data.startswith("spec_"), RegistrationStates.choosing_specialization)
async def choose_specialization(callback: CallbackQuery, state: FSMContext):
    spec_id = callback.data.replace("spec_", "")
    await state.update_data(specialization=spec_id)
    
    await callback.message.edit_text(MESSAGES['ask_fio'], parse_mode="HTML")
    await state.set_state(RegistrationStates.entering_fio)
    await callback.answer()

@router.message(RegistrationStates.entering_fio)
async def enter_fio(message: Message, state: FSMContext):
    fio = message.text.strip()
    
    if len(fio) < 5:
        await message.answer("⚠️ ФИО слишком короткое. Введите полное ФИО:")
        return
    
    await state.update_data(fio=fio)
    await message.answer(
        MESSAGES['ask_position'],
        reply_markup=get_positions_keyboard(POSITIONS)
    )
    await state.set_state(RegistrationStates.choosing_position)

@router.callback_query(F.data.startswith("pos_page_"))
async def position_page(callback: CallbackQuery):
    page = int(callback.data.replace("pos_page_", ""))
    await callback.message.edit_reply_markup(reply_markup=get_positions_keyboard(POSITIONS, page))
    await callback.answer()

@router.callback_query(F.data.startswith("pos_"), RegistrationStates.choosing_position)
async def choose_position(callback: CallbackQuery, state: FSMContext):
    if "page" in callback.data:
        return
    
    pos_idx = int(callback.data.replace("pos_", ""))
    position = POSITIONS[pos_idx]
    await state.update_data(position=position)
    
    await callback.message.edit_text(
        MESSAGES['ask_department'],
        reply_markup=get_departments_keyboard(DEPARTMENTS)
    )
    await state.set_state(RegistrationStates.choosing_department)
    await callback.answer()

@router.callback_query(F.data.startswith("dept_page_"))
async def department_page(callback: CallbackQuery):
    page = int(callback.data.replace("dept_page_", ""))
    await callback.message.edit_reply_markup(reply_markup=get_departments_keyboard(DEPARTMENTS, page))
    await callback.answer()

@router.callback_query(F.data.startswith("dept_"), RegistrationStates.choosing_department)
async def choose_department(callback: CallbackQuery, state: FSMContext):
    if "page" in callback.data:
        return
    
    dept_idx = int(callback.data.replace("dept_", ""))
    department = DEPARTMENTS[dept_idx]
    await state.update_data(department=department)
    
    await callback.message.edit_text(
        MESSAGES['ask_difficulty'],
        reply_markup=get_difficulty_keyboard(),
        parse_mode="HTML"
    )
    await state.set_state(RegistrationStates.choosing_difficulty)
    await callback.answer()
REGEOF

echo "✅ handlers/registration.py создан"

echo ""
echo "✅ Handlers и Database созданы!"

