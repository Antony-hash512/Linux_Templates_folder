#!/bin/bash

#проверяем на права суперпользователя
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\033[31mERROR: This script must be run as root\033[0m" >&2
    exit 1
fi

# Определение цветовых переменных
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
GRAY='\033[90m'
LIGHT_PURPLE='\033[95m'
LIGHT_BLUE='\033[94m'
BOLD='\033[1m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
NC='\033[0m'

#инициализация временного файла для точек монтирования (нужно в начале)
> /tmp/btrfs_temp_mounts.txt

one_line() {
    # Получаем данные из первого аргумента
    local input_data="$1"
    
    # Заменяем переносы строк на запятую
    echo "$input_data" | tr '\n' ' ' | sed 's/ $//'
}

# Функция для окрашивания указанного текста в строке
color_text_in_string() {
    local original_string="$1"    # Исходная строка
    local text_to_color="$2"      # Текст, который нужно окрасить
    local color_code="$3"         # Код цвета для окрашивания
    
    # Находим позицию текста в строке
    local position=$(echo -n "$original_string" | grep -bo "$text_to_color" | cut -d':' -f1)
    
    # Если текст найден
    if [ -n "$position" ]; then
        # Получаем длину текста
        local text_length=${#text_to_color}
        
        # Разделяем строку на части до и после окрашиваемого текста
        local prefix=$(echo -n "$original_string" | cut -c1-$position)
        local suffix=$(echo -n "$original_string" | cut -c$((position+text_length+1))-)
        
        # Возвращаем строку с окрашенным текстом
        echo "${prefix}${color_code}${text_to_color}${NC}${suffix}"
    else
        # Возвращаем исходную строку, если текст не найден
        echo "$original_string"
    fi
}

get_btrfs_mountpoint() {
    local btrfs_device=$1 #требуется указать полный путь к устройству
    local btrfs_mountpoint=""
    
    #проверяем есть ли запись в массиве ALL_BTRFS_MOUNTPOINTS
    if [[ -n "${ALL_BTRFS_MOUNTPOINTS[$btrfs_device]}" ]]; then
        btrfs_mountpoint="${ALL_BTRFS_MOUNTPOINTS[$btrfs_device]}"
    else
        #при помощи команды findmnt проверяем, существует ли хотя бы одна точка монтирования для данного устройства
        if ! findmnt "$btrfs_device" > /dev/null 2>&1; then
            #создаём временный каталог
            btrfs_mountpoint=$(mktemp -d)
            #монтируем устройство в временный каталог
            mount "$btrfs_device" "$btrfs_mountpoint"
            
            # Сохраняем точку монтирования в файле для последующего размонтирования
            echo "$btrfs_mountpoint" >> /tmp/btrfs_temp_mounts.txt
            
            # Выводим сообщение в stderr, чтобы не влиять на вывод функции
            echo -e "${GRAY}${ITALIC}Добавлена временная точка монтирования: $btrfs_mountpoint${NC}" >&2
            
            #проверяем, что устройство успешно смонтировалось
            if ! findmnt "$btrfs_device" > /dev/null 2>&1; then
                echo -e "${RED}Устройство $btrfs_device не смонтировалось${NC}" >&2
                exit 1
            fi
        else
            #получаем точку монтирования для устройства (первую попавшуюся, если их несколько)
            btrfs_mountpoint=$(findmnt -l -n -o TARGET "$btrfs_device" | sed -n '1p')
        fi
        #добавляем точку монтирования в массив ALL_BTRFS_MOUNTPOINTS
        ALL_BTRFS_MOUNTPOINTS[$btrfs_device]="$btrfs_mountpoint"
    fi
    echo "$btrfs_mountpoint"
}

get_btrfs_subvolumes() {
    local btrfs_device=$1
    #получаем точку монтирования для устройства
    local btrfs_mountpoint=$(get_btrfs_mountpoint "$btrfs_device")

    local subvolumes="$(btrfs subvolume list "$btrfs_mountpoint" | grep 'level 5 path' | sed -E 's/.*level 5 path[[:space:]]+([^[:space:]]+).*/\1/')"
    echo "$subvolumes"
}

make_pause() {
    echo ""
    read -p "Нажмите Enter для продолжения"
    echo ""
}



#создаём ассоциативный массив, который будет находить хотя бы одну точку монтирования по имени устройства btrfs
declare -A ALL_BTRFS_MOUNTPOINTS

echo -e "${CYAN}Информация о вносимых изменениях:${NC}"
echo -e "${GRAY}${ITALIC}${UNDERLINE}Построение информации...${NC}"

#создаём временные файлы и сохраняем имя в переменные
LSBLK_RAW_INFO=$(mktemp)
LSBLK_RAW_INFO_UPDATED=$(mktemp)
#записываем содержимое во временный файл
#RM или RO - нужно дописать в конец строки чтобы при добавлении дополнительного параметра всё было выровнено по правому краю
lsblk -o NAME,TYPE,FSTYPE,SIZE,RM,RO,ROTA,UUID,MOUNTPOINTS > $LSBLK_RAW_INFO

#записываем первую строку с добавочным текстом (если нужен) во второй временный файл
echo "$(head -n 1 $LSBLK_RAW_INFO)" > $LSBLK_RAW_INFO_UPDATED


#проходися по файлу начиная со второй строки в цикле
while IFS= read -r line; do
    #дублируем строку как есть до изменения
    line_orig="$line"
    #заменяем '│ ' на '│·' чтобы избежать ошибочного разбиения на слова
    line=$(echo "$line" | sed 's/│ /│·/g')
    if [[ "$(echo "$line" | awk '{print $3}')" == "btrfs" ]]; then
        # Используем функцию для окрашивания слова "btrfs"
        line_colored=$(color_text_in_string "$line_orig" "btrfs" "$CYAN")
        echo -e "$line_colored" >> $LSBLK_RAW_INFO_UPDATED
        
        #получаем базовое имя устройства
        device_basename=$(echo "$line" | awk '{print $1}')
        #удаляем любые символы отображающие древовидную структуру из начала строки
        device_basename=$(echo "$device_basename" | sed 's/^[├─└│·]*//')
        #определяем полное имя устройства
        if [[ "$(echo "$line" | awk '{print $2}')" == "lvm" ]]; then
            device_fullname="/dev/mapper/$device_basename"
        elif [[ "$(echo "$line" | awk '{print $2}')" == "part" ]]; then
            device_fullname="/dev/$device_basename"
        fi
        #используем функцию get_btrfs_subvolumes
        #если вывод пустой, то выводим сообщение об отсутствии сабволюмов и не делаем дальнейших проверок
        if [[ -z "$(get_btrfs_subvolumes "$device_fullname")" ]]; then
            echo -e "${GRAY}${ITALIC}${UNDERLINE}На устройстве $device_fullname нет сабволюмов${NC}" >> $LSBLK_RAW_INFO_UPDATED
        else
            existing_subvolumes_string=$(one_line "$(get_btrfs_subvolumes "$device_fullname")")
            #получаем массив из строки
            read -r -a existing_subvolumes <<< "$existing_subvolumes_string"
            #выводим сабволюмы, используем функцию one_line чтобы отобразить их в одной строке, если их несколько
            echo -e "!${BOLD}Имеющиеся сабволюмы:${NC} ${CYAN}$existing_subvolumes_string${NC}" >> $LSBLK_RAW_INFO_UPDATED
            
        fi
    elif [[ "$(echo "$line" | awk '{print $3}')" == "LVM2_member" ]]; then
        #окрашиваем находку
        line_colored=$(color_text_in_string "$line_orig" "LVM2_member" "$YELLOW")
        echo -e "$line_colored" >> $LSBLK_RAW_INFO_UPDATED
    elif [[ "$(echo "$line" | awk '{print $3}')" == "ext4" ]]; then
        #окрашиваем находку
        line_colored=$(color_text_in_string "$line_orig" "ext4" "$LIGHT_PURPLE")
        echo -e "$line_colored" >> $LSBLK_RAW_INFO_UPDATED
    elif [[ "$(echo "$line" | awk '{print $3}')" == "crypto_LUKS" ]]; then
        #окрашиваем находку
        line_colored=$(color_text_in_string "$line_orig" "crypto_LUKS" "$LIGHT_BLUE")
        echo -e "$line_colored" >> $LSBLK_RAW_INFO_UPDATED
    else
        #пишем строку как есть
        echo "$line_orig" >> $LSBLK_RAW_INFO_UPDATED
    fi
done < <(sed '1d' $LSBLK_RAW_INFO)

# Обновляем первый временный файл и обнуляем второй
cp $LSBLK_RAW_INFO_UPDATED $LSBLK_RAW_INFO
#выводим содержимое временного файла
cat $LSBLK_RAW_INFO


#размонтируем временные точки монтирования btrfs
if [ -f /tmp/btrfs_temp_mounts.txt ]; then
    echo -e "${CYAN}Список временных точек монтирования:${NC}"
    cat /tmp/btrfs_temp_mounts.txt
    
    while read -r mountpoint; do
        if [ -z "$mountpoint" ]; then
            continue
        fi
        
        echo -e "${GRAY}${ITALIC}${UNDERLINE}Размонтируем точку монтирования $mountpoint${NC}"
        if umount "$mountpoint"; then
            echo -e "${GREEN}Успешно размонтировано: $mountpoint${NC}"
            # Удаляем временный каталог, если он был создан с помощью mktemp
            if [[ "$mountpoint" == /tmp/tmp.* ]]; then
                rmdir "$mountpoint" 2>/dev/null
            fi
        else
            echo -e "${RED}Ошибка при размонтировании: $mountpoint${NC}"
            echo -e "${YELLOW}Попробуем принудительное размонтирование...${NC}"
            if umount -f "$mountpoint"; then
                echo -e "${GREEN}Успешно размонтировано с флагом -f: $mountpoint${NC}"
                # Удаляем временный каталог, если он был создан с помощью mktemp
                if [[ "$mountpoint" == /tmp/tmp.* ]]; then
                    rmdir "$mountpoint" 2>/dev/null
                fi
            else
                echo -e "${RED}Не удалось размонтировать даже с флагом -f: $mountpoint${NC}"
                echo -e "${YELLOW}Проверьте, не используются ли файлы на этой точке монтирования.${NC}"
                lsof | grep "$mountpoint" || echo "Файлы не найдены в использовании"
            fi
        fi
    done < /tmp/btrfs_temp_mounts.txt
    
    # Очищаем файл
    > /tmp/btrfs_temp_mounts.txt
else
    echo -e "${YELLOW}Нет временных точек монтирования для размонтирования${NC}"
fi

#удаляем временные файлы
rm -f $LSBLK_RAW_INFO
rm -f $LSBLK_RAW_INFO_UPDATED
exit 0




