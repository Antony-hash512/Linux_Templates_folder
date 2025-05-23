#!/bin/bash

set -euo pipefail

# === Настройки ===
SRC_MNT="/mnt/input"
SRC_SUBVOL="@arch_gnome"
DEST_MNT="/mnt/output"
REMOUNT_RO=true  # Перемонтировать подтом в режиме read-only
VERBOSE=true     # Подробный вывод rsync

# === Вспомогательные функции ===
log() {
    echo "[+] $1"
}

warn() {
    echo "[!] $1"
}

error() {
    echo "[x] $1"
}

# === Опции rsync ===
RSYNC_OPTS="-aAX"
if [ "$VERBOSE" = true ]; then
    RSYNC_OPTS+="v"
fi

# === Проверка и возможное перемонтирование в режиме read-only ===
if [ "$REMOUNT_RO" = true ]; then
    log "Пытаемся перемонтировать $SRC_MNT в режиме read-only"
    sudo mount -o remount,ro "$SRC_MNT" 2>/dev/null || {
        warn "Не удалось перемонтировать. Возможно файловая система уже в режиме read-only."
    }
fi

# === Копирование прямым методом ===
log "Переходим к прямому копированию данных"

# Создаем целевой подтом
log "Создаем целевой подтом $SRC_SUBVOL в $DEST_MNT"
if ! sudo btrfs subvolume create "$DEST_MNT/$SRC_SUBVOL" 2>/dev/null; then
    warn "Не удалось создать подтом $DEST_MNT/$SRC_SUBVOL"
    
    # Проверяем, существует ли уже целевой подтом
    if sudo btrfs subvolume show "$DEST_MNT/$SRC_SUBVOL" &>/dev/null; then
        warn "Подтом $DEST_MNT/$SRC_SUBVOL уже существует, продолжаем..."
    else
        error "Невозможно создать целевой подтом. Завершаем работу."
        exit 1
    fi
fi

# Копируем корневой подтом
log "Копирование данных из $SRC_MNT/$SRC_SUBVOL в $DEST_MNT/$SRC_SUBVOL"
if ! sudo rsync $RSYNC_OPTS --exclude='.snapshot*' "$SRC_MNT/$SRC_SUBVOL/" "$DEST_MNT/$SRC_SUBVOL/"; then
    error "Ошибка при копировании данных для $SRC_SUBVOL"
    warn "Продолжаем, но копирование может быть неполным"
fi

# === Список вложенных сабволюмов ===
log "Ищем вложенные сабволюмы..."
if mapfile -t SUBVOLS < <(
    sudo btrfs subvolume list -o "$SRC_MNT/$SRC_SUBVOL" 2>/dev/null \
        | sed -E 's/^.* path //' \
        | grep -v -E '(snapshots|_snap|_send)' \
        | grep -v '^\.snapshot'
); then
    if [ ${#SUBVOLS[@]} -gt 0 ]; then
        log "Найдено ${#SUBVOLS[@]} вложенных подтомов"
    else
        log "Вложенных подтомов не найдено"
        SUBVOLS=()
    fi
else
    warn "Не удалось получить список вложенных подтомов"
    # Попробуем альтернативный метод поиска
    log "Использую альтернативный метод поиска вложенных подтомов..."
    
    if mapfile -t SUBVOLS < <(
        find "$SRC_MNT/$SRC_SUBVOL" -type d -exec sudo btrfs subvolume show {} \; 2>/dev/null \
            | grep -B1 "^ *Path:" | grep "^ *Path:" | sed -E 's/^ *Path: //g' \
            | grep -v "^$SRC_MNT/$SRC_SUBVOL$" | sort | uniq
    ); then
        if [ ${#SUBVOLS[@]} -gt 0 ]; then
            log "Найдено ${#SUBVOLS[@]} вложенных подтомов альтернативным методом"
        else
            log "Вложенных подтомов не найдено (альтернативный метод)"
            SUBVOLS=()
        fi
    else
        warn "Не удалось найти вложенные подтомы даже альтернативным методом"
        SUBVOLS=()
    fi
fi

# === Обработка вложенных сабволюмов ===
if [ ${#SUBVOLS[@]} -gt 0 ]; then
    for subvol_rel in "${SUBVOLS[@]}"; do
        # Извлекаем относительный путь подтома
        rel_path="${subvol_rel#"$SRC_MNT/"}"
        log "Обработка вложенного подтома: $rel_path"
        
        # Создаем родительские директории
        target_dir=$(dirname "$DEST_MNT/$rel_path")
        sudo mkdir -p "$target_dir"
        
        # Создаем целевой подтом
        if ! sudo btrfs subvolume create "$DEST_MNT/$rel_path" 2>/dev/null; then
            warn "Не удалось создать подтом $DEST_MNT/$rel_path"
            
            # Проверяем, существует ли уже целевой подтом
            if sudo btrfs subvolume show "$DEST_MNT/$rel_path" &>/dev/null; then
                warn "Подтом $DEST_MNT/$rel_path уже существует, продолжаем..."
            else
                error "Невозможно создать $DEST_MNT/$rel_path. Пропускаем..."
                continue
            fi
        fi
        
        # Копируем данные подтома
        log "Копирование данных для $rel_path"
        if ! sudo rsync $RSYNC_OPTS --exclude='.snapshot*' "$SRC_MNT/$rel_path/" "$DEST_MNT/$rel_path/"; then
            error "Ошибка при копировании данных для $rel_path"
            warn "Продолжаем со следующим подтомом"
        fi
    done
fi

log "Процесс копирования завершён"
warn "ВАЖНО: Данные были скопированы через rsync, это НЕ полноценная отправка btrfs"
warn "    Метаданные btrfs (COW, сжатие и т.д.) могут быть не сохранены полностью"

