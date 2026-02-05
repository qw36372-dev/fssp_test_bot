#!/usr/bin/env python3
"""Финальная проверка проекта"""

from pathlib import Path
import json

print("=" * 70)
print("🔍 ФИНАЛЬНАЯ ПРОВЕРКА ПРОЕКТА")
print("=" * 70)

base = Path(".")

# 1. Проверка структуры
print("\n📁 СТРУКТУРА ПРОЕКТА:")
required_dirs = [
    "config",
    "database", 
    "library",
    "handlers",
    "data/questions"
]

for d in required_dirs:
    path = base / d
    status = "✅" if path.exists() else "❌"
    print(f"   {status} {d}/")

# 2. Проверка критических файлов
print("\n📄 КРИТИЧЕСКИЕ ФАЙЛЫ:")
required_files = [
    "main.py",
    "requirements.txt",
    ".env.example",
    "README.md",
    "config/settings.py",
    "config/__init__.py",
    "database/db.py",
    "database/__init__.py",
    "library/states.py",
    "library/models.py",
    "library/keyboards.py",
    "library/middlewares.py",
    "library/timers.py",
    "library/utils.py",
    "library/question_loader.py",
    "handlers/start.py",
    "handlers/registration.py",
    "handlers/testing.py",
    "data/positions.json",
    "data/departments.json"
]

missing = []
for f in required_files:
    path = base / f
    if path.exists():
        size = path.stat().st_size
        print(f"   ✅ {f} ({size} bytes)")
    else:
        print(f"   ❌ {f} ОТСУТСТВУЕТ!")
        missing.append(f)

# 3. Проверка вопросов
print("\n📝 ФАЙЛЫ ВОПРОСОВ:")
questions_dir = base / "data/questions"
json_files = sorted(questions_dir.glob("*.json"))

total_questions = 0
for jf in json_files:
    try:
        with open(jf, 'r', encoding='utf-8') as f:
            questions = json.load(f)
        count = len(questions)
        total_questions += count
        print(f"   ✅ {jf.name}: {count} вопросов")
    except Exception as e:
        print(f"   ❌ {jf.name}: ОШИБКА - {e}")

print(f"\n   📊 ВСЕГО ВОПРОСОВ: {total_questions}")

# 4. Проверка positions и departments
print("\n👥 ДОПОЛНИТЕЛЬНЫЕ ДАННЫЕ:")
try:
    with open(base / "data/positions.json", 'r', encoding='utf-8') as f:
        positions = json.load(f)
    print(f"   ✅ Должностей: {len(positions)}")
except Exception as e:
    print(f"   ❌ positions.json: {e}")

try:
    with open(base / "data/departments.json", 'r', encoding='utf-8') as f:
        departments = json.load(f)
    print(f"   ✅ Подразделений: {len(departments)}")
except Exception as e:
    print(f"   ❌ departments.json: {e}")

# 5. Итоговая статистика
print("\n" + "=" * 70)
print("📊 ИТОГОВАЯ СТАТИСТИКА:")
print(f"   Python файлов: {len(list(base.rglob('*.py')))}")
print(f"   JSON файлов: {len(list(base.rglob('*.json')))}")
print(f"   Всего вопросов: {total_questions}")
print(f"   Специализаций: {len(json_files)}")

if missing:
    print(f"\n❌ ОТСУТСТВУЮЩИЕ ФАЙЛЫ: {len(missing)}")
    for f in missing:
        print(f"      - {f}")
    print("\n⚠️  ПРОЕКТ НЕ ГОТОВ К ИСПОЛЬЗОВАНИЮ!")
else:
    print("\n✅ ВСЕ ФАЙЛЫ НА МЕСТЕ!")
    print("✅ ПРОЕКТ ПОЛНОСТЬЮ ГОТОВ К ИСПОЛЬЗОВАНИЮ!")

print("=" * 70)

