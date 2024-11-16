#!/bin/bash

# Устанавливаем значение по умолчанию
random=false
way="zero"
files=()

# В начале скрипта определяем тип ОС
OS_TYPE=${OS_TYPE:-"Linux"}  # По умолчанию Linux, но можно задать MacOS
# Это специальный синтаксис подстановки значения по умолчанию в bash.
# Если переменная `OS_TYPE` уже установлена и не пуста - использовать её значение
# Если не установлена или пуста - установить значение по умолчанию "Linux"

# Обрабатываем ключи и собираем файлы
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--random)
      random=true
      way="urandom"
      shift
      ;;
    *)
      # Добавляем аргумент в массив files, если это не имя скрипта
      if [ "$1" != "$(basename "$0")" ]; then
        files+=("$1")
      fi
      shift
      ;;
  esac
done

# Функция для обработки файла
process_file() {
  local file="$1"
  size=$(stat --format=%s "$file")
  # Округление размера до ближайшего большего, кратного 4096
  rounded_size=$(( (size + 4095) / 4096 * 4096 ))
  dd if=/dev/$way of="$file" bs=4096 count=$((rounded_size / 4096)) status=none
  echo "Файл $file перезаписан $rounded_size $([ "$way" = "zero" ] && echo "нулями" || echo "случайными байтами")."
}

# Функция для оповещения пользователя о необычных файлах
check_unusual_file() {
    local file="$1"
    if [ -L "$file" ]; then
        echo "ВНИМАНИЕ: Найдена символическая ссылка: $file"
    elif [ -d "$file" ]; then
        echo "ВНИМАНИЕ: Найдена директория: $file"
    elif [ -c "$file" ]; then
        echo "ВНИМАНИЕ: Найдено символьное устройство: $file"
    elif [ -b "$file" ]; then
        echo "ВНИМАНИЕ: Найдено блочное устройство: $file"
    elif [ -p "$file" ]; then
        echo "ВНИМАНИЕ: Найден именованный канал: $file"
    elif [ -S "$file" ]; then
        echo "ВНИМАНИЕ: Найден сокет: $file"
    fi
}

# Функция для обработки жёстких ссылок (если жёстких ссылок нет, то будет выполнена функция process_file для обычного файла)
handle_hardlink() {
    local file="$1"
    local links

    # Используем соответствующий синтаксис stat в зависимости от OS_TYPE
    case "$OS_TYPE" in
        "Linux")
            # Для Linux используем формат -c
            links=$(stat -c "%h" "$file")
            ;;
        "MacOS")
            # Для MacOS используем формат -f
            links=$(stat -f "%l" "$file")
            ;;
        *)
            # Если указан неизвестный тип ОС
            echo "Неизвестный тип ОС: $OS_TYPE"
            return 1
            ;;
    esac

    # Проверяем успешность выполнения команды stat
    if [ $? -ne 0 ]; then
        echo "Ошибка при получении информации о файле: $file"
        return 1
    fi

    # Если найдена жёсткая ссылка (количество ссылок больше 1)
    if [ "$links" -gt 1 ]; then
        # Проверяем, не было ли уже глобального разрешения
        if [ "$PROCESS_ALL_HARDLINKS" != "true" ]; then
            echo "ВНИМАНИЕ: Найдена жёсткая ссылка: $file"
            echo "Количество ссылок: $links"
            echo "Обработать этот файл? (yes/no/all)"
            read -r answer
            case "$answer" in
                "yes")
                    # Обработать только текущий файл
                    process_file "$file"
                    ;;
                "all")
                    # Обработать этот и все последующие файлы с жёсткими ссылками
                    PROCESS_ALL_HARDLINKS="true"
                    process_file "$file"
                    ;;
                "no")
                    echo "Пропускаем файл: $file"
                    ;;
                *)
                    echo "Неверный ответ. Пропускаем файл."
                    ;;
            esac
        else
            # Если было глобальное разрешение "all"
            process_file "$file"
        fi
    else
        # Если это обычный файл без дополнительных жёстких ссылок
        process_file "$file"
    fi
}

# Инициализация глобальной переменной для отслеживания выбора "all"
PROCESS_ALL_HARDLINKS="false"

# Перебор каждого файла/каталога в списке
for item in "${files[@]}"; do
  if [ -f "$item" ]; then
    handle_hardlink "$item"
  elif [ -d "$item" ]; then
    # Рекурсивный обход каталога
    while IFS= read -r -d '' file; do
      if [ -f "$file" ]; then
        handle_hardlink "$file"
      else
        check_unusual_file "$file"
      fi
    done < <(find "$item" -print0)
  else
    echo "Путь $item не найден."
  fi
done
