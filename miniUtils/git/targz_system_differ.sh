#!/bin/bash
# Требуется установленный meld и git

# Переменные для ветвей Git
BRANCH1=dev


# Путь к репозиторию
PATH2REP=~/git/Pure-Arch-Linux_-installer-v2

# Список архивов для сравнения
ARCHIVES=(
    "homefiles.tar.gz"
    "homefiles_openbox.tar.gz"
    "homefiles_hyprland.tar.gz"
    "homefiles_gnome.tar.gz"
    "rootfiles.tar.gz"
)

# Проверка существования веток
cd "$PATH2REP" || { echo "Не удалось перейти в $PATH2REP" >&2; exit 1; }

if ! git rev-parse --verify "$BRANCH1" >/dev/null 2>&1; then
    echo "Ошибка: ветка '$BRANCH1' не существует" >&2
    exit 1
fi


# Показываем список архивов
echo "Доступные архивы для сравнения:"
for i in "${!ARCHIVES[@]}"; do
    echo "$((i+1)). ${ARCHIVES[i]}"
done

# Запрашиваем выбор пользователя и проверяем корректность ввода в цикле
while true; do
    read -p "Введите номер архива для сравнения (1-${#ARCHIVES[@]}): " CHOICE
    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#ARCHIVES[@]}" ]; then
        break
    fi
    echo "Ошибка: введите число от 1 до ${#ARCHIVES[@]}" >&2
done

# Получаем выбранный архив (индексы массива начинаются с 0)
ARCHIVE="${ARCHIVES[$((CHOICE-1))]}"

# Проверка существования архива
if ! git ls-tree -r "$BRANCH1" | grep -q "$ARCHIVE"; then
    echo "Ошибка: файл '$ARCHIVE' не найден в ветке '$BRANCH1'" >&2
    exit 1
fi

TMPDIR1=$(mktemp -d)
TMPDIR2=$(mktemp -d)

# Очистка временных файлов при выходе
trap "rm -rf $TMPDIR1 $TMPDIR2" EXIT

cd "$PATH2REP" || { echo "Не удалось перейти в $PATH2REP" >&2; exit 1; }

echo "Извлечение $ARCHIVE из ветки $BRANCH1..."
git show "$BRANCH1:$ARCHIVE" | tar -xzf - -C "$TMPDIR1"

# записывает в список список файлов
LIST_FILES=$(ls -R "$TMPDIR1")


# Если имя архива начинается с root, то...
if [[ "$ARCHIVE" == "rootfiles.tar.gz" ]]; then
    START_PATH="/"
    IS_ROOT=true
else
    START_PATH="$HOME/"
    IS_ROOT=false
fi

# копирует файлы в списке в нужную директорию
if [ "$IS_ROOT" = true ]; then
    # получаем имя пользователя
    USER=$(whoami)
    for FILE in $LIST_FILES; do
        sudo cp -r "$START_PATH$FILE" "$TMPDIR2/$FILE"
    done
    # меняем владельца файлов на пользователя
    sudo chown -R $USER:$USER "$TMPDIR2"
else
    for FILE in $LIST_FILES; do
        cp -r "$START_PATH$FILE" "$TMPDIR2/$FILE"
    done
fi

# сравниваем файлы в директориях
meld "$TMPDIR1" "$TMPDIR2"

# удаляем временные директории
rm -rf "$TMPDIR1" "$TMPDIR2"

