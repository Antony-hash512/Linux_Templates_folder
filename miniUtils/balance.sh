#!/bin/bash

MOUNT_POINT="/mnt/gigabox"
DLIMIT=10
MLIMIT=5
SLEEP_SEC=5

echo "🔄 Запуск пошаговой балансировки для $MOUNT_POINT"
echo "🧮 Data limit: $DLIMIT GiB, Metadata limit: $MLIMIT GiB"
echo "⏱️ Пауза между шагами: $SLEEP_SEC сек."

while true; do
    STATUS=$(btrfs balance status "$MOUNT_POINT")
    
    if echo "$STATUS" | grep -q "No balance found"; then
        echo "✅ Балансировка завершена."
        break
    elif echo "$STATUS" | grep -q "Running"; then
        echo "⏳ Балансировка уже запущена, ждём завершения..."
        sleep "$SLEEP_SEC"
        continue
    fi

    echo "🚀 Новый шаг балансировки..."
    btrfs balance start -dlimit=$DLIMIT -mlimit=$MLIMIT "$MOUNT_POINT"

    echo "🛌 Ожидание $SLEEP_SEC сек перед следующим шагом..."
    sleep "$SLEEP_SEC"
done
