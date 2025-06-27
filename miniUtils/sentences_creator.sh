#!/bin/bash

# Обработка ключей помощи
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Скрипт читает слова из INPUT_FILE и генерирует предложения через gemini-cli"
    echo "Использование: $0 INPUT_FILE OUTPUT_FILE"
    echo "  INPUT_FILE  - файл со словами по одному на строке"
    echo "  OUTPUT_FILE - выходной файл для предложений в YAML"
    exit 0
fi

# Проверка наличия аргументов
if [[ $# -lt 2 ]]; then
    echo "Ошибка: недостаточно аргументов"
    echo "Использование: $0 INPUT_FILE OUTPUT_FILE"
    echo "Справочная информация: $0 -h"
    exit 1
fi

# Проверка доступности команды gemini
if ! command -v gemini >/dev/null 2>&1; then
    echo "Ошибка: команда 'gemini' не найдена. Установите gemini-cli и убедитесь, что она в PATH"
    echo "ссылка на установку: https://github.com/google-gemini/gemini-cli"
    exit 1
fi

# Файл, из которого читаем слова
INPUT_FILE=$1
OUTPUT_FILE=$2
MODEL_GEMINI="gemini-2.5-flash"

# Проверяем, существует ли файл
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Ошибка: Файл '$INPUT_FILE' не найден!"
    exit 1
fi

# Читаем файл построчно
# IFS= и -r нужны для корректного чтения строк, содержащих пробелы или спецсимволы
while IFS= read -r word || [[ -n "$word" ]]; do
    # Пропускаем пустые строки
    if [[ -z "$word" ]]; then
        continue
    fi

    echo "--- Обрабатываю слово: '$word' ---"

    # Формируем промпт для Gemini.
    # Вы можете менять его как угодно.
    # Например, попросить составить предложение для определенного уровня языка (A2, B1, C1).
    PROMPT="Составь одно предложение на английском со словом '${word}'."

    # Вызываем gemini-cli, передавая ему промпт.
    # Кавычки вокруг "$PROMPT" обязательны, чтобы промпт передался как один аргумент.
    CURRENT_RESPONCE=$(gemini -m "$MODEL_GEMINI" -p "$PROMPT" < /dev/null)
    echo "$CURRENT_RESPONCE"
    echo "\"$word\" : \"$CURRENT_RESPONCE\"" >> $OUTPUT_FILE
    # Добавляем пустую строку для лучшей читаемости вывода
    echo ""

done < "$INPUT_FILE"

echo "--- Обработка завершена ---"
