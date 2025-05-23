#!/bin/bash

DEFAULT_DIR="/home/fireice/data/extra/vm_disks/win_xp"

# Обработка аргументов командной строки
ISO_PATH=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --iso=*)
            ISO_PATH="${1#*=}"
            shift
            ;;
        *)
            echo "Использование: $0 [--iso=путь/к/файлу.iso]"
            exit 1
            ;;
    esac
done

# Проверка и настройка пути к ISO
CDROM_OPTION=""
if [ ! -z "$ISO_PATH" ]; then
    # Если путь не абсолютный, добавляем DEFAULT_DIR
    if [[ ! "$ISO_PATH" = /* ]]; then
        ISO_PATH="$DEFAULT_DIR/$ISO_PATH"
    fi
    
    # Проверка существования файла
    if [ ! -f "$ISO_PATH" ]; then
        echo "Ошибка: ISO файл не найден: $ISO_PATH"
        exit 1
    fi
    
    CDROM_OPTION="-cdrom $ISO_PATH"
fi

qemu-system-i386 \
    -enable-kvm \
    -m 2G \
    -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time \
    -smp 1 \
    -drive file=$DEFAULT_DIR/winxp_ru100G.qcow2,if=ide,media=disk,format=qcow2 \
    -virtfs local,path=$DEFAULT_DIR/shared_dir,mount_tag=shared_dir,security_model=none \
    $CDROM_OPTION \
    -netdev user,id=mynet0,hostfwd=tcp::10139-:139,hostfwd=tcp::10445-:445 \
    -device rtl8139,netdev=mynet0 \
    -display gtk,zoom-to-fit=off \
    -vga std \
    -audiodev pa,id=pa,server=unix:${XDG_RUNTIME_DIR}/pulse/native \
    -device ac97,audiodev=pa \
    -usb \
    -device usb-tablet
    

# Настройка Samba на Arch Linux:
# 1. Установка: sudo pacman -S samba
# 2. Создание конфигурации:
#    sudo cp /etc/samba/smb.conf.default /etc/samba/smb.conf
#    sudo nano /etc/samba/smb.conf
#
# 3. Добавьте в smb.conf:
#    [global]
#    workgroup = WORKGROUP
#    security = user
#    map to guest = bad user
#
#    [winxp_share]
#    path = /home/fireice/data/extra/vm_disks/win_xp/shared_dir
#    browsable = yes
#    writable = yes
#    guest ok = yes
#    read only = no
#    create mask = 0777
#    directory mask = 0777
#
# 4. Создание пользователя Samba:
#    sudo smbpasswd -a fireice
#
# 5. Запуск и активация службы:
#    sudo systemctl enable smb nmb
#    sudo systemctl start smb nmb
#
# 6. Настройка брандмауэра:
#    sudo firewall-cmd --permanent --add-service=samba
#    sudo firewall-cmd --reload
#
# 7. В Windows XP подключение: \\192.168.122.1\winxp_share
#    или через проброшенные порты: \\127.0.0.1:10445\winxp_share
# 8. Просмотр правильного адреса:
#    nmblookup -S WORKGROUP
# у меня: \\192.168.9.154\winxp_share
