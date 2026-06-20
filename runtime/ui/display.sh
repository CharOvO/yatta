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
  if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
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
  yatta_has_tty && [[ "$locale_value" =~ (UTF-8|utf8|utf-8) ]]
}

yatta_ui_brand() {
  printf '%s\n' "${YATTA_COLOR_BOLD}Yatta ${YATTA_VERSION:-dev}! server init${YATTA_COLOR_RESET}" >&2
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

yatta_ui_multiline_input() {
  local prompt="$1"
  local line
  printf '%s\n' "$prompt" >&2
  printf '%s\n' "输入完成后提交空行；非交互环境下默认留空。" >&2
  if ! yatta_has_tty; then
    printf '%s\n' "${YATTA_TEST_MULTILINE_INPUT:-}"
    return 0
  fi
  while true; do
    IFS= read -r line </dev/tty || break
    line="${line//$'\r'/}"
    [[ -z "$line" ]] && break
    printf '%s\n' "$line"
  done
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

yatta_ui_multi_select() {
  local prompt="$1"
  local selected_csv="${2:-}"
  local locked_csv="${3:-}"
  shift 3
  if yatta_has_tty; then
    yatta_ui_multi_select_arrow "$prompt" "$selected_csv" "$locked_csv" "$@"
  else
    yatta_ui_multi_select_numbered "$prompt" "$selected_csv" "$locked_csv" "$@"
  fi
}

yatta_ui_multi_select_flags_init() {
  local selected_csv="$1"
  local locked_csv="$2"
  local count="$3"
  local item index
  YATTA_UI_MULTI_SELECTED=()
  YATTA_UI_MULTI_LOCKED=()
  for ((index = 0; index < count; index++)); do
    YATTA_UI_MULTI_SELECTED[$index]="false"
    YATTA_UI_MULTI_LOCKED[$index]="false"
  done
  IFS=',' read -ra YATTA_UI_MULTI_SELECTED_ITEMS <<<"$selected_csv"
  for item in "${YATTA_UI_MULTI_SELECTED_ITEMS[@]}"; do
    item="${item//[[:space:]]/}"
    [[ "$item" =~ ^[0-9]+$ ]] && ((item >= 0 && item < count)) && YATTA_UI_MULTI_SELECTED[$item]="true"
  done
  IFS=',' read -ra YATTA_UI_MULTI_LOCKED_ITEMS <<<"$locked_csv"
  for item in "${YATTA_UI_MULTI_LOCKED_ITEMS[@]}"; do
    item="${item//[[:space:]]/}"
    if [[ "$item" =~ ^[0-9]+$ ]] && ((item >= 0 && item < count)); then
      YATTA_UI_MULTI_LOCKED[$item]="true"
      YATTA_UI_MULTI_SELECTED[$item]="true"
    fi
  done
}

yatta_ui_multi_select_emit() {
  local index
  for index in "${!YATTA_UI_MULTI_SELECTED[@]}"; do
    [[ "${YATTA_UI_MULTI_SELECTED[$index]}" == "true" ]] && printf '%s\n' "$index"
  done
}

yatta_ui_multi_select_numbered() {
  local prompt="$1"
  local selected_csv="${2:-}"
  local locked_csv="${3:-}"
  shift 3
  local options=("$@")
  local answer item index marker locked_label
  yatta_ui_multi_select_flags_init "$selected_csv" "$locked_csv" "${#options[@]}"
  printf '%s\n' "$prompt" >&2
  for index in "${!options[@]}"; do
    marker="[ ]"
    [[ "${YATTA_UI_MULTI_SELECTED[$index]}" == "true" ]] && marker="[x]"
    locked_label=""
    [[ "${YATTA_UI_MULTI_LOCKED[$index]}" == "true" ]] && locked_label=" locked"
    printf '  %d) %s %s%s\n' "$((index + 1))" "$marker" "${options[$index]}" "$locked_label" >&2
  done
  printf '%s' "输入要选中的序号，多个序号用逗号分隔；直接回车使用当前选择: " >&2
  if yatta_has_tty; then
    IFS= read -r answer </dev/tty || answer=""
  else
    IFS= read -r answer || answer=""
  fi
  answer="${answer//$'\r'/}"
  if [[ -n "$answer" ]]; then
    for index in "${!options[@]}"; do
      if [[ "${YATTA_UI_MULTI_LOCKED[$index]}" == "true" ]]; then
        YATTA_UI_MULTI_SELECTED[$index]="true"
      else
        YATTA_UI_MULTI_SELECTED[$index]="false"
      fi
    done
    IFS=',' read -ra YATTA_UI_MULTI_ANSWER_ITEMS <<<"$answer"
    for item in "${YATTA_UI_MULTI_ANSWER_ITEMS[@]}"; do
      item="${item//[[:space:]]/}"
      if [[ ! "$item" =~ ^[0-9]+$ ]] || ((item < 1 || item > ${#options[@]})); then
        yatta_log_warn "忽略无效序号：${item}"
        continue
      fi
      index=$((item - 1))
      if [[ "${YATTA_UI_MULTI_LOCKED[$index]}" == "true" ]]; then
        yatta_log_warn "该项目不可取消：${options[$index]}"
        YATTA_UI_MULTI_SELECTED[$index]="true"
        continue
      fi
      YATTA_UI_MULTI_SELECTED[$index]="true"
    done
  fi
  yatta_ui_multi_select_emit
}

yatta_ui_multi_select_arrow() {
  local prompt="$1"
  local selected_csv="${2:-}"
  local locked_csv="${3:-}"
  shift 3
  local options=("$@")
  local selected=0
  local key rest index marker
  yatta_ui_multi_select_flags_init "$selected_csv" "$locked_csv" "${#options[@]}"
  printf '%s\n' "$prompt" >/dev/tty
  printf '%s\n' "↑/↓ 移动，Space 切换，Enter 确认。" >/dev/tty
  while true; do
    for index in "${!options[@]}"; do
      marker="[ ]"
      [[ "${YATTA_UI_MULTI_SELECTED[$index]}" == "true" ]] && marker="[x]"
      if [[ "$index" -eq "$selected" ]]; then
        printf '\r\033[K  %s %s%s %s%s\n' "$YATTA_SYMBOL_ARROW" "$YATTA_COLOR_BOLD" "$marker" "${options[$index]}" "$YATTA_COLOR_RESET" >/dev/tty
      else
        printf '\r\033[K    %s %s\n' "$marker" "${options[$index]}" >/dev/tty
      fi
    done
    IFS= read -rsn1 key </dev/tty || {
      yatta_ui_multi_select_numbered "$prompt" "$selected_csv" "$locked_csv" "${options[@]}"
      return
    }
    case "$key" in
      "")
        yatta_ui_multi_select_emit
        return 0
        ;;
      " ")
        if [[ "${YATTA_UI_MULTI_LOCKED[$selected]}" == "true" ]]; then
          printf '\a' >/dev/tty
        elif [[ "${YATTA_UI_MULTI_SELECTED[$selected]}" == "true" ]]; then
          YATTA_UI_MULTI_SELECTED[$selected]="false"
        else
          YATTA_UI_MULTI_SELECTED[$selected]="true"
        fi
        ;;
      $'\033')
        IFS= read -rsn2 -t 0.1 rest </dev/tty || rest=""
        case "$rest" in
          "[A") ((selected > 0)) && selected=$((selected - 1)) ;;
          "[B") ((selected < ${#options[@]} - 1)) && selected=$((selected + 1)) ;;
        esac
        ;;
    esac
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
