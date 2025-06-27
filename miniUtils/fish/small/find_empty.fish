#!/usr/bin/env fish

echo "🔍 Поиск пустых файлов в текущем каталоге:"
set found 0
for f in *
    if test -f "$f" -a (stat -c %s "$f") -eq 0
        echo "📄 Пустой файл: $f"
        set found 1
    end
end

if test $found -eq 0
    echo "✅ Пустых файлов не найдено."
end
