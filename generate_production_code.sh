#!/bin/bash
# Генератор production-ready кода для ФССП бота

echo "🚀 Генерация production-ready кода..."
echo ""

# Создаём все критические файлы через heredoc для скорости

# 1. library/states.py
cat > library/states.py << 'EOF'
"""FSM States"""
from aiogram.fsm.state import State, StatesGroup

class RegistrationStates(StatesGroup):
    choosing_specialization = State()
    entering_fio = State()
    choosing_position = State()
    choosing_department = State()
    choosing_difficulty = State()

class TestingStates(StatesGroup):
    in_test = State()
    test_completed = State()
EOF

# 2. library/models.py  
cat > library/models.py << 'EOF'
"""Data models"""
from dataclasses import dataclass, field
from typing import List, Dict, Optional
from datetime import datetime

@dataclass
class User:
    telegram_id: int
    full_name: str
    position: Optional[str] = None
    department: Optional[str] = None

@dataclass
class Question:
    question: str
    options: List[str]
    correct_answers: str

@dataclass
class TestSession:
    user_id: int
    specialization: str
    difficulty: str
    questions: List[Question] = field(default_factory=list)
    current_question: int = 0
    user_answers: List[str] = field(default_factory=list)
    start_time: datetime = field(default_factory=datetime.now)
    test_id: Optional[int] = None
EOF

# 3. library/question_loader.py
cat > library/question_loader.py << 'EOF'
"""Question loader"""
import json
import random
from pathlib import Path
from typing import List, Dict
from config.settings import QUESTIONS_DIR

class QuestionLoader:
    @staticmethod
    def load_questions(specialization: str, count: int) -> List[Dict]:
        file_path = QUESTIONS_DIR / f"{specialization}.json"
        with open(file_path, 'r', encoding='utf-8') as f:
            all_questions = json.load(f)
        
        # Берём случайные вопросы
        if len(all_questions) > count:
            return random.sample(all_questions, count)
        return all_questions[:count]
EOF

# 4. library/utils.py
cat > library/utils.py << 'EOF'
"""Utilities"""
from config.settings import GRADING_SCALE

def calculate_grade(percentage: float) -> str:
    for min_p, max_p, grade in GRADING_SCALE:
        if min_p <= percentage <= max_p:
            return grade
    return "НЕУДОВЛЕТВОРИТЕЛЬНО ❌"

def format_time(seconds: int) -> str:
    minutes, secs = divmod(seconds, 60)
    return f"{minutes:02d}:{secs:02d}"

def check_answer(user_answer: str, correct_answer: str) -> bool:
    user_set = set(user_answer.split(',')) if user_answer else set()
    correct_set = set(correct_answer.split(','))
    return user_set == correct_set
EOF

echo "✅ library/ создан"

# 5. library/keyboards.py
cat > library/keyboards.py << 'EOF'
"""Keyboards"""
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils.keyboard import InlineKeyboardBuilder
from typing import List
from config.settings import SPECIALIZATIONS, DIFFICULTY_LEVELS, ANSWER_EMOJIS

def get_specializations_keyboard() -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for spec_id, spec_data in SPECIALIZATIONS.items():
        builder.button(
            text=spec_data['name'],
            callback_data=f"spec_{spec_id}"
        )
    builder.adjust(1)
    return builder.as_markup()

def get_positions_keyboard(positions: List[str], page: int = 0) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    page_size = 6
    start = page * page_size
    end = start + page_size
    
    for pos in positions[start:end]:
        builder.button(text=pos, callback_data=f"pos_{positions.index(pos)}")
    
    # Навигация
    nav_buttons = []
    if page > 0:
        nav_buttons.append(InlineKeyboardButton(text="◀️ Назад", callback_data=f"pos_page_{page-1}"))
    if end < len(positions):
        nav_buttons.append(InlineKeyboardButton(text="Далее ▶️", callback_data=f"pos_page_{page+1}"))
    
    builder.adjust(2)
    if nav_buttons:
        builder.row(*nav_buttons)
    
    return builder.as_markup()

def get_departments_keyboard(departments: List[str], page: int = 0) -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    page_size = 6
    start = page * page_size
    end = start + page_size
    
    for dept in departments[start:end]:
        builder.button(text=dept[:50], callback_data=f"dept_{departments.index(dept)}")
    
    nav_buttons = []
    if page > 0:
        nav_buttons.append(InlineKeyboardButton(text="◀️ Назад", callback_data=f"dept_page_{page-1}"))
    if end < len(departments):
        nav_buttons.append(InlineKeyboardButton(text="Далее ▶️", callback_data=f"dept_page_{page+1}"))
    
    builder.adjust(2)
    if nav_buttons:
        builder.row(*nav_buttons)
    
    return builder.as_markup()

def get_difficulty_keyboard() -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    for diff_id, diff_data in DIFFICULTY_LEVELS.items():
        builder.button(text=diff_data['name'], callback_data=f"diff_{diff_id}")
    builder.adjust(1)
    return builder.as_markup()

def get_answer_keyboard(options: List[str], selected: List[int] = None) -> InlineKeyboardMarkup:
    if selected is None:
        selected = []
    
    builder = InlineKeyboardBuilder()
    for i, option in enumerate(options[:5]):  # Максимум 5 вариантов
        emoji = ANSWER_EMOJIS[i]
        checkmark = "✅" if i in selected else ""
        text = f"{checkmark}{emoji} {option[:30]}"
        builder.button(text=text, callback_data=f"ans_{i}")
    
    builder.adjust(2)
    builder.row(InlineKeyboardButton(text="➡️ Далее", callback_data="next_question"))
    
    return builder.as_markup()

def get_results_keyboard() -> InlineKeyboardMarkup:
    builder = InlineKeyboardBuilder()
    builder.button(text="📋 Показать ответы", callback_data="show_answers")
    builder.button(text="🔄 Повторить тест", callback_data="restart_test")
    builder.button(text="📊 История", callback_data="show_history")
    builder.button(text="🏠 Главное меню", callback_data="main_menu")
    builder.adjust(2)
    return builder.as_markup()
EOF

echo "✅ keyboards.py создан"

# 6. library/middlewares.py
cat > library/middlewares.py << 'EOF'
"""Middlewares"""
import time
import logging
from typing import Callable, Dict, Any, Awaitable
from aiogram import BaseMiddleware
from aiogram.types import Update

logger = logging.getLogger(__name__)

class AntiSpamMiddleware(BaseMiddleware):
    def __init__(self, rate_limit: int = 3):
        self.rate_limit = rate_limit
        self.user_last_request: Dict[int, float] = {}
    
    async def __call__(
        self,
        handler: Callable[[Update, Dict[str, Any]], Awaitable[Any]],
        event: Update,
        data: Dict[str, Any]
    ) -> Any:
        user = data.get('event_from_user')
        if not user:
            return await handler(event, data)
        
        user_id = user.id
        current_time = time.time()
        
        if user_id in self.user_last_request:
            time_passed = current_time - self.user_last_request[user_id]
            if time_passed < 1.0 / self.rate_limit:
                return None
        
        self.user_last_request[user_id] = current_time
        return await handler(event, data)

class ErrorHandlerMiddleware(BaseMiddleware):
    async def __call__(
        self,
        handler: Callable[[Update, Dict[str, Any]], Awaitable[Any]],
        event: Update,
        data: Dict[str, Any]
    ) -> Any:
        try:
            return await handler(event, data)
        except Exception as e:
            logger.error(f"Error handling update: {e}", exc_info=True)
            return None
EOF

echo "✅ middlewares.py создан"

# 7. library/timers.py
cat > library/timers.py << 'EOF'
"""Test timers"""
import asyncio
from datetime import datetime, timedelta
from typing import Dict

class TimerManager:
    def __init__(self):
        self.timers: Dict[int, asyncio.Task] = {}
    
    def start_timer(self, user_id: int, duration: int, callback):
        if user_id in self.timers:
            self.timers[user_id].cancel()
        
        task = asyncio.create_task(self._timer_task(user_id, duration, callback))
        self.timers[user_id] = task
    
    async def _timer_task(self, user_id: int, duration: int, callback):
        await asyncio.sleep(duration * 60)
        await callback(user_id)
        if user_id in self.timers:
            del self.timers[user_id]
    
    def stop_timer(self, user_id: int):
        if user_id in self.timers:
            self.timers[user_id].cancel()
            del self.timers[user_id]
    
    def get_remaining_time(self, user_id: int, start_time: datetime, duration: int) -> str:
        elapsed = (datetime.now() - start_time).total_seconds()
        remaining = max(0, duration * 60 - elapsed)
        minutes, seconds = divmod(int(remaining), 60)
        return f"{minutes:02d}:{seconds:02d}"
EOF

echo "✅ timers.py создан"

echo ""
echo "📝 Всего создано файлов: 7"
echo "✅ Библиотека library/ готова!"

