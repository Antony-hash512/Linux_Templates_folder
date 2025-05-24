#!/bin/bash

# Тройка: путь, имя ISO, метка тома
declare -a iso_entries=(
  "/home/user/project1|project1.iso|PROJECT_1"
  "/home/user/project 2|project2.iso|ПРОЕКТ_2"
  "/home/user/books and docs|books.iso|BOOKS"
)

# Проверка флага кириллицы
support_cyrillic=false
if [[ "$1" == "--cyrillic" ]]; then
  support_cyrillic=true
fi

# Вывод списка
echo "Доступные проекты для сборки ISO:"
for i in "${!iso_entries[@]}"; do
  IFS='|' read -r path iso label <<< "${iso_entries[$i]}"
  printf "%2d) %-20s => %s [%s]\n" "$((i+1))" "$path" "$iso" "$label"
done

# Ввод от пользователя
read -p "Введите номер проекта для сборки ISO: " choice
index=$((choice - 1))

if [[ $index -lt 0 || $index -ge ${#iso_entries[@]} ]]; then
  echo "❌ Неверный выбор."
  exit 1
fi

IFS=' ' read -r path iso label <<< "${iso_entries[$index]}"

# Уточнение про поддержку кириллицы
if ! $support_cyrillic; then
  read -p "Добавить поддержку кириллических имён? [y/N]: " add_cyr
  [[ "$add_cyr" =~ ^[Yy]$ ]] && support_cyrillic=true
fi

# Сборка ISO
echo "📦 Создание ISO '$iso' из '$path' с меткой '$label'..."

xorriso -as mkisofs \
  -o "$iso" \
  -V "$label" \
  -J -joliet-long -R \
  $( $support_cyrillic && echo "-input-charset utf-8" ) \
  "$path"

echo "✅ ISO собрано: $iso"
