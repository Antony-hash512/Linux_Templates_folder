
#!/bin/bash

# Использование:
# ./tarz-update.sh [--noram] archive.tar.gz file1 [file2 ...]

set -e

USE_RAM=true

# Проверка на флаг --help
if [[ "$1" == "--help" ]]; then
  echo "\nUsage: $0 [--noram] archive.tar.gz file1 [file2 ...]"
  echo "\nOptions:"
  echo "  --noram     Use disk instead of RAM (for large archives)"
  echo "  --help      Show this help message"
  exit 0
fi

# Проверка на флаг --noram
if [[ "$1" == "--noram" ]]; then
  USE_RAM=false
  shift
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 [--noram] archive.tar.gz file1 [file2 ...]"
  exit 1
fi

ARCHIVE_GZ="$1"
shift
FILES=("$@")

# Проверки
if [[ ! -f "$ARCHIVE_GZ" ]]; then
  echo "Error: archive '$ARCHIVE_GZ' not found."
  exit 1
fi

for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Error: file '$file' not found."
    exit 1
  fi
done

# Временный путь для .tar
if $USE_RAM; then
  TMPDIR=$(mktemp -d --tmpdir=/dev/shm tarz.XXXXXX)
else
  TMPDIR=$(mktemp -d)
fi
trap "rm -rf \"$TMPDIR\"" EXIT

ARCHIVE_TAR="$TMPDIR/archive.tar"

# Распаковать gzip во временный файл
echo "[*] Unpacking $ARCHIVE_GZ to RAM-disk: $ARCHIVE_TAR..."
gunzip -c "$ARCHIVE_GZ" > "$ARCHIVE_TAR"

# Обновить файлы в tar
for file in "${FILES[@]}"; do
  echo "[*] Updating: $file"
  tar --update -f "$ARCHIVE_TAR" "$file"
done

# Сжать обратно
echo "[*] Repacking $ARCHIVE_TAR to $ARCHIVE_GZ..."
gzip -c "$ARCHIVE_TAR" > "$ARCHIVE_GZ"

echo "[✓] Done."
