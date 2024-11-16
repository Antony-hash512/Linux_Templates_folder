#!/bin/bash

# Инициализация переменных для аргументов с ключами
keyArg1="значение1_по_умолчанию"
keyArg2="значение2_по_умолчанию"

# Цикл обработки аргументов командной строки
for arg in "$@"; do
    case $arg in
        -key1=*) keyArg1="${arg#*=}" ; shift;; # извлекаем значение после "="
        -key2=*) keyArg2="${arg#*=}" ; shift;;
        *) break;;
    esac
done

echo "Значение ключевого аргумента 1: $keyArg1"
echo "Значение ключевого аргумента 2: $keyArg2"


# Обработка оставшихся аргументов без ключей
for arg in "$@"; do
    echo "Обработка аргумента без ключа: $arg"
done