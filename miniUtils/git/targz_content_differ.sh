#!/bin/bash
# Скрипт для сравнения содержимого архивов в двух ветках Git
# Требуется установленный meld и git

# Переменные для ветвей Git
BRANCH1=dev
BRANCH2=hypr_edits

# Путь к репозиторию
PATH2REP=~/git/Pure-Arch-Linux_-installer-v2

# Список архивов для сравнения
ARCHIVES=(
    "homefiles.tar.gz"
    "rootfiles.tar.gz"
)

# Проверка существования веток
cd "$PATH2REP" || { echo "Не удалось перейти в $PATH2REP" >&2; exit 1; }

if ! git rev-parse --verify "$BRANCH1" >/dev/null 2>&1; then
    echo "Ошибка: ветка '$BRANCH1' не существует" >&2
    exit 1
fi

if ! git rev-parse --verify "$BRANCH2" >/dev/null 2>&1; then
    echo "Ошибка: ветка '$BRANCH2' не существует" >&2
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

# Проверка существования архива в обеих ветках
if ! git ls-tree -r "$BRANCH1" | grep -q "$ARCHIVE"; then
    echo "Ошибка: файл '$ARCHIVE' не найден в ветке '$BRANCH1'" >&2
    exit 1
fi

if ! git ls-tree -r "$BRANCH2" | grep -q "$ARCHIVE"; then
    echo "Ошибка: файл '$ARCHIVE' не найден в ветке '$BRANCH2'" >&2
    exit 1
fi

# Функция для сравнения архивов
function compare_archives() {
    local branch1=$1
    local branch2=$2
    local archive=$3
    local repo_path=$4

    # Создание временных директорий
    TMPDIR1=$(mktemp -d)
    TMPDIR2=$(mktemp -d)

    # Очистка временных файлов при выходе
    trap "rm -rf $TMPDIR1 $TMPDIR2" EXIT

    # Переход в репозиторий
    cd "$repo_path" || { echo "Не удалось перейти в $repo_path" >&2; exit 1; }
    
    # Извлечение архивов из указанных веток
    echo "Извлечение $archive из ветки $branch1..."
    git show "$branch1:$archive" | tar -xzf - -C "$TMPDIR1"
    
    echo "Извлечение $archive из ветки $branch2..."
    git show "$branch2:$archive" | tar -xzf - -C "$TMPDIR2"

    # Запуск meld для сравнения
    meld "$TMPDIR1" "$TMPDIR2"
}

# Вызов функции сравнения с передачей пути к репозиторию
compare_archives "$BRANCH1" "$BRANCH2" "$ARCHIVE" "$PATH2REP"



