#!/usr/bin/env python3
"""
Pechernyi Compress CLI

Usage:
    pechernyi <filepath>
"""

import sys
from pathlib import Path

from .compress import compress_file
from .detect import detect_file_type, should_compress


def print_usage():
    print("Використання: pechernyi <filepath>")


def main():
    if len(sys.argv) != 2:
        print_usage()
        sys.exit(1)

    filepath = Path(sys.argv[1])

    # Check file exists
    if not filepath.exists():
        print(f"❌ Файл не знайдено: {filepath}")
        sys.exit(1)

    if not filepath.is_file():
        print(f"❌ Це не файл: {filepath}")
        sys.exit(1)

    filepath = filepath.resolve()

    # Detect file type
    file_type = detect_file_type(filepath)

    print(f"Виявлено: {file_type}")

    # Check if compressible
    if not should_compress(filepath):
        print("Пропуск: файл не є природною мовою (код/конфіг)")
        sys.exit(0)

    print("Запуск pechernyi-стиснення...\n")

    try:
        success = compress_file(filepath)

        if success:
            print("\nСтиснення успішно завершено")
            backup_path = filepath.with_name(filepath.stem + ".original.md")
            print(f"Стиснуто:  {filepath}")
            print(f"Оригінал:  {backup_path}")
            sys.exit(0)
        else:
            print("\n❌ Стиснення не вдалося після повторних спроб")
            sys.exit(2)

    except KeyboardInterrupt:
        print("\nПерервано користувачем")
        sys.exit(130)

    except Exception as e:
        print(f"\n❌ Помилка: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
