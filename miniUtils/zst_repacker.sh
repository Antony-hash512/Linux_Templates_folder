#/bin/sh

#задаём степень сжатия
COMPRESSION_LEVEL=$2
#задаём значение по умолчанию
if [ -z "$COMPRESSION_LEVEL" ]; then
    COMPRESSION_LEVEL=9
fi

export ZSTD_CLEVEL=$COMPRESSION_LEVEL

INPUT_ARCH=$1

INPUT_ARCH_BASENAME=$(echo "$INPUT_ARCH" | sed 's/\.tar\..*//')

if [ ! -f "$INPUT_ARCH" ]; then
    echo "Input archive not found"
    exit 1
fi

if [ -f "${INPUT_ARCH_BASENAME}.tar.zst" ]; then
    echo "Output archive already exists"
    exit 1
fi


#создаем временную директорию
TEMP_DIR=$(mktemp -d)

#распаковываем архив
tar --no-same-owner -xvf "$INPUT_ARCH" -C "$TEMP_DIR"

#если версия tar больше 1.31, то перепаковываем архив в zstd напрямую без внешнего компрессора
if [ $(tar --version | grep -oP 'tar \(GNU tar\) \K[\d.]+') -gt 1.31 ]; then
    tar --zstd --numeric-owner -cvf "${INPUT_ARCH_BASENAME}.tar.zst" -C "$TEMP_DIR" .
else
    tar -I zstd --numeric-owner -cvf "${INPUT_ARCH_BASENAME}.tar.zst" -C "$TEMP_DIR" .
fi

#удаляем временную директорию
rm -rf "$TEMP_DIR"

