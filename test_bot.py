"""Test script for FSSP Test Bot."""

import json
import sys
from pathlib import Path


def test_data_files():
    """Test data files integrity."""
    print("🔍 Тестирование файлов данных...\n")
    
    errors = []
    
    # Test positions
    try:
        with open('data/positions.json', 'r', encoding='utf-8') as f:
            positions = json.load(f)
        if len(positions) < 10:
            errors.append("Недостаточно должностей")
        else:
            print(f"✅ Должности: {len(positions)}")
    except Exception as e:
        errors.append(f"Ошибка загрузки должностей: {e}")
    
    # Test departments
    try:
        with open('data/departments.json', 'r', encoding='utf-8') as f:
            departments = json.load(f)
        if len(departments) < 50:
            errors.append("Недостаточно подразделений")
        else:
            print(f"✅ Подразделения: {len(departments)}")
    except Exception as e:
        errors.append(f"Ошибка загрузки подразделений: {e}")
    
    # Test questions
    specs = [
        'ispolniteli', 'oupds', 'doznanie', 'starshie',
        'oko', 'rozisk', 'informatizaciya', 'kadri', 'bezopasnost'
    ]
    
    total_questions = 0
    for spec in specs:
        try:
            with open(f'data/questions/{spec}.json', 'r', encoding='utf-8') as f:
                questions = json.load(f)
            
            # Validate each question
            for i, q in enumerate(questions):
                if not all(key in q for key in ['question', 'options', 'correct_answers']):
                    errors.append(f"{spec}: вопрос {i+1} имеет неполную структуру")
                if len(q.get('options', [])) < 2:
                    errors.append(f"{spec}: вопрос {i+1} имеет менее 2 вариантов")
            
            total_questions += len(questions)
            print(f"✅ {spec}: {len(questions)} вопросов")
            
        except Exception as e:
            errors.append(f"Ошибка загрузки {spec}: {e}")
    
    print(f"\n📊 Всего вопросов: {total_questions}")
    
    return errors


def test_configuration():
    """Test configuration."""
    print("\n🔍 Тестирование конфигурации...\n")
    
    errors = []
    
    try:
        from config.settings import (
            SPECIALIZATIONS, DIFFICULTY_LEVELS,
            GRADING_SCALE, EMOJI_NUMBERS
        )
        
        print(f"✅ Специализаций: {len(SPECIALIZATIONS)}")
        print(f"✅ Уровней сложности: {len(DIFFICULTY_LEVELS)}")
        print(f"✅ Градация оценок: {len(GRADING_SCALE)}")
        print(f"✅ Emoji кнопок: {len(EMOJI_NUMBERS)}")
        
        # Check all specializations have question files
        for spec_key, spec_data in SPECIALIZATIONS.items():
            filepath = Path('data/questions') / spec_data['questions_file']
            if not filepath.exists():
                errors.append(f"Файл вопросов не найден: {filepath}")
        
    except Exception as e:
        errors.append(f"Ошибка загрузки конфигурации: {e}")
    
    return errors


def test_modules():
    """Test module imports."""
    print("\n🔍 Тестирование модулей...\n")
    
    errors = []
    modules = [
        ('config', 'Config'),
        ('database', 'Database'),
        ('library.states', 'States'),
        ('library.keyboards', 'Keyboards'),
        ('library.utils', 'Utils'),
        ('library.question_loader', 'QuestionLoader'),
    ]
    
    for module_name, display_name in modules:
        try:
            __import__(module_name)
            print(f"✅ {display_name}")
        except ImportError as e:
            if 'aiogram' in str(e) or 'aiosqlite' in str(e):
                print(f"⚠️  {display_name} (требует установки зависимостей)")
            else:
                errors.append(f"Ошибка импорта {display_name}: {e}")
        except Exception as e:
            errors.append(f"Ошибка в {display_name}: {e}")
    
    return errors


def main():
    """Main test function."""
    print("=" * 80)
    print("🧪 ТЕСТИРОВАНИЕ FSSP TEST BOT")
    print("=" * 80)
    print()
    
    all_errors = []
    
    # Test data files
    errors = test_data_files()
    all_errors.extend(errors)
    
    # Test configuration
    errors = test_configuration()
    all_errors.extend(errors)
    
    # Test modules
    errors = test_modules()
    all_errors.extend(errors)
    
    # Summary
    print("\n" + "=" * 80)
    if all_errors:
        print(f"❌ НАЙДЕНО ОШИБОК: {len(all_errors)}")
        print("=" * 80)
        for i, error in enumerate(all_errors, 1):
            print(f"\n{i}. {error}")
        sys.exit(1)
    else:
        print("✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!")
        print("=" * 80)
        print("\nБот готов к запуску!")
        print("\nДля запуска:")
        print("  1. Установите зависимости: pip install -r requirements.txt")
        print("  2. Настройте .env файл")
        print("  3. Запустите: python main.py")
        sys.exit(0)


if __name__ == '__main__':
    main()
