clean() {
  local dry_run=0
  local force=0
  local target=

  # Аргументы
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      --force) force=1 ;;
      -*) echo "❌ Unknown option: $arg" >&2; return 1 ;;
      *) target="$arg" ;;
    esac
  done

  if [[ -z "$target" ]]; then
    echo "Usage: clean /path/to/dir [--dry-run] [--force]"
    return 1
  fi

  if [[ ! -d "$target" ]]; then
    echo "❌ Not a directory: $target"
    return 1
  fi

  # Защита от опасных путей, если нет --force
  case "$target" in
    /|/root|/home|/boot|/etc|/bin|/sbin|/usr|/var)
      if (( force == 0 )); then
        echo "🚫 Refusing to clean critical directory without --force: $target"
        return 1
      fi
      ;;
  esac

  echo "🧹 Cleaning contents of: $target"

  if (( dry_run )); then
    echo "🧪 Dry run: would run:"
    echo "rm -rf -- \"$target\"/* \"$target\"/.[^.]* \"$target\"/.??*"
  else
    rm -rf -- "$target"/* "$target"/.[^.]* "$target"/.??*
  fi
}
