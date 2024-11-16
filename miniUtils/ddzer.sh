#!/bin/bash

# Устанавливаем значение по умолчанию
random=false
way="zero"
files=()

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

# Перебор каждого файла в списке
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    size=$(stat --format=%s "$file")
    # Округление размера до ближайшего большего, кратного 4096
    rounded_size=$(( (size + 4095) / 4096 * 4096 ))
    dd if=/dev/$way of="$file" bs=4096 count=$((rounded_size / 4096)) status=none
    echo "Файл $file перезаписан $rounded_size $([ "$way" = "zero" ] && echo "нулями" || echo "случайными байтами")."
  else
    echo "Файл $file не найден."
  fi
done
