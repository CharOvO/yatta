# 这里实现零外部依赖的终端交互。UI 函数尽量只负责显示和读取输入，
# 不判断服务器环境，也不执行系统命令。

YATTA_COLOR_RESET=""
YATTA_COLOR_DIM=""
YATTA_COLOR_BOLD=""
YATTA_COLOR_OK=""
YATTA_COLOR_WARN=""
YATTA_COLOR_ERROR=""
YATTA_COLOR_INFO=""

YATTA_SYMBOL_OK="OK"
YATTA_SYMBOL_WARN="WARN"
YATTA_SYMBOL_ERROR="ERR"
YATTA_SYMBOL_INFO="INFO"
YATTA_SYMBOL_ARROW=">"
YATTA_SPINNER_FRAMES=("-" "\\" "|" "/")

yatta_ui_init() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    YATTA_COLOR_RESET=$'\033[0m'
    YATTA_COLOR_DIM=$'\033[2m'
    YATTA_COLOR_BOLD=$'\033[1m'
    YATTA_COLOR_OK=$'\033[32m'
    YATTA_COLOR_WARN=$'\033[33m'
    YATTA_COLOR_ERROR=$'\033[31m'
    YATTA_COLOR_INFO=$'\033[36m'
  fi

  if yatta_ui_utf8_enabled; then
    YATTA_SYMBOL_OK="✓"
    YATTA_SYMBOL_WARN="!"
    YATTA_SYMBOL_ERROR="✗"
    YATTA_SYMBOL_INFO="•"
    YATTA_SYMBOL_ARROW="›"
    YATTA_SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  fi
}

yatta_ui_utf8_enabled() {
  local locale_value="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
  [[ -t 1 && "$locale_value" =~ (UTF-8|utf8|utf-8) ]]
}

yatta_ui_brand() {
  printf '%s\n' "${YATTA_COLOR_BOLD}Yatta! server init${YATTA_COLOR_RESET}" >&2
  printf '%s\n' "${YATTA_COLOR_DIM}把新 Ubuntu 服务器整理到可日常使用的基础状态。${YATTA_COLOR_RESET}" >&2
  printf '%s\n' >&2
}

yatta_ui_section() {
  printf '\n%s%s %s%s\n' "$YATTA_COLOR_BOLD" "$YATTA_SYMBOL_ARROW" "$1" "$YATTA_COLOR_RESET" >&2
}

yatta_status_label() {
  case "$1" in
    ok) printf '%s' "ok" ;;
    warn) printf '%s' "warn" ;;
    error) printf '%s' "error" ;;
    info | *) printf '%s' "info" ;;
  esac
}

yatta_log_info() {
  printf '%s[%s]%s %s\n' "$YATTA_COLOR_INFO" "$YATTA_SYMBOL_INFO" "$YATTA_COLOR_RESET" "$1" >&2
}

yatta_log_ok() {
  printf '%s[%s]%s %s\n' "$YATTA_COLOR_OK" "$YATTA_SYMBOL_OK" "$YATTA_COLOR_RESET" "$1" >&2
}

yatta_log_warn() {
  printf '%s[%s]%s %s\n' "$YATTA_COLOR_WARN" "$YATTA_SYMBOL_WARN" "$YATTA_COLOR_RESET" "$1" >&2
}

yatta_log_error() {
  printf '%s[%s]%s %s\n' "$YATTA_COLOR_ERROR" "$YATTA_SYMBOL_ERROR" "$YATTA_COLOR_RESET" "$1" >&2
}

yatta_ui_input() {
  local prompt="$1"
  local default="${2:-}"
  local answer
  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  if yatta_has_tty; then
    IFS= read -r answer </dev/tty || answer=""
  else
    IFS= read -r answer || answer=""
  fi
  answer="${answer//$'\r'/}"
  if [[ -z "$answer" ]]; then
    answer="$default"
  fi
  printf '%s\n' "$answer"
}

yatta_ui_confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local suffix answer
  if [[ "$default" == "y" ]]; then
    suffix="Y/n"
  else
    suffix="y/N"
  fi
  while true; do
    printf '%s [%s]: ' "$prompt" "$suffix" >&2
    if yatta_has_tty; then
      IFS= read -r answer </dev/tty || answer=""
    else
      IFS= read -r answer || answer=""
    fi
    answer="${answer//$'\r'/}"
    answer="${answer:-$default}"
    case "$answer" in
      y | Y | yes | YES) return 0 ;;
      n | N | no | NO) return 1 ;;
      *) yatta_log_warn "请输入 y 或 n。" ;;
    esac
  done
}

yatta_ui_select() {
  local prompt="$1"
  local default_index="$2"
  shift 2
  if yatta_has_tty; then
    yatta_ui_select_arrow "$prompt" "$default_index" "$@"
  else
    yatta_ui_select_numbered "$prompt" "$default_index" "$@"
  fi
}

yatta_ui_select_numbered() {
  local prompt="$1"
  local default_index="$2"
  shift 2
  local options=("$@")
  local answer index
  printf '%s\n' "$prompt" >&2
  for index in "${!options[@]}"; do
    printf '  %d) %s\n' "$((index + 1))" "${options[$index]}" >&2
  done
  printf '选择 [%d]: ' "$((default_index + 1))" >&2
  if yatta_has_tty; then
    IFS= read -r answer </dev/tty || answer=""
  else
    IFS= read -r answer || answer=""
  fi
  answer="${answer//$'\r'/}"
  answer="${answer:-$((default_index + 1))}"
  if [[ "$answer" =~ ^[0-9]+$ ]] && ((answer >= 1 && answer <= ${#options[@]})); then
    printf '%s\n' "${options[$((answer - 1))]}"
    return 0
  fi
  yatta_log_warn "输入无效，使用默认选项。"
  printf '%s\n' "${options[$default_index]}"
}

yatta_ui_select_arrow() {
  local prompt="$1"
  local selected="$2"
  shift 2
  local options=("$@")
  local key rest index
  printf '%s\n' "$prompt" >/dev/tty
  while true; do
    for index in "${!options[@]}"; do
      if [[ "$index" -eq "$selected" ]]; then
        printf '\r\033[K  %s %s%s%s\n' "$YATTA_SYMBOL_ARROW" "$YATTA_COLOR_BOLD" "${options[$index]}" "$YATTA_COLOR_RESET" >/dev/tty
      else
        printf '\r\033[K    %s\n' "${options[$index]}" >/dev/tty
      fi
    done
    IFS= read -rsn1 key </dev/tty || {
      yatta_ui_select_numbered "$prompt" "$selected" "${options[@]}"
      return
    }
    if [[ "$key" == "" ]]; then
      printf '%s\n' "${options[$selected]}"
      return 0
    fi
    if [[ "$key" == $'\033' ]]; then
      IFS= read -rsn2 -t 0.1 rest </dev/tty || rest=""
      case "$rest" in
        "[A") ((selected > 0)) && selected=$((selected - 1)) ;;
        "[B") ((selected < ${#options[@]} - 1)) && selected=$((selected + 1)) ;;
      esac
    fi
    printf '\033[%dA' "${#options[@]}" >/dev/tty
  done
}

yatta_ui_spinner() {
  local message="$1"
  shift
  local pid frame_index frame rc
  if ! yatta_has_tty; then
    yatta_log_info "$message"
    "$@"
    return $?
  fi

  "$@" &
  pid=$!
  frame_index=0
  while kill -0 "$pid" >/dev/null 2>&1; do
    frame="${YATTA_SPINNER_FRAMES[$((frame_index % ${#YATTA_SPINNER_FRAMES[@]}))]}"
    printf '\r%s %s' "$frame" "$message" >&2
    frame_index=$((frame_index + 1))
    sleep 0.1
  done
  wait "$pid"
  rc=$?
  printf '\r\033[K' >&2
  return "$rc"
}
