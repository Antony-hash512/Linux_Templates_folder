#!/bin/bash

# Список файлов для обработки
files=("file1.txt" "file2.txt" "anotherfile.dat")

# Перебор каждого файла в списке
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    size=$(stat --format=%s "$file")
    # Округление размера до ближайшего большего, кратного 4096
    rounded_size=$(( (size + 4095) / 4096 * 4096 ))
    dd if=/dev/urandom of="$file" bs=4096 count=$((rounded_size / 4096)) status=none
    echo "Файл $file перезаписан $rounded_size случайными байтами."
  else
    echo "Файл $file не найден."
  fi
done
