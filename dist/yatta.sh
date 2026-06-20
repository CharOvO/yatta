#!/usr/bin/env bash
# 此文件由 yatta build 生成，请勿手写修改。
# Yatta version: 1.0.0
YATTA_VERSION='1.0.0'

# ===== runtime/core/prelude.sh =====
# 这里保存 runtime 的共享状态和小型工具函数。它必须最先被拼接，
# 让后续 UI、系统探测、适配器和主流程都能使用同一套计划与模块注册结构。

YATTA_MODULE_IDS=()
YATTA_MODULE_NAMES=()
YATTA_MODULE_STAGES=()
YATTA_MODULE_GROUPS=()
YATTA_MODULE_RISKS=()
YATTA_MODULE_RUNTIME_DEFAULTS=()
YATTA_MODULE_LOCKED=()
YATTA_MODULE_ENABLED=()
YATTA_MODULE_PROMPT_FNS=()
YATTA_MODULE_PRE_APPLY_FNS=()
YATTA_MODULE_APPLY_FNS=()
YATTA_MODULE_POST_APPLY_FNS=()

YATTA_PLAN_MODULES=()
YATTA_PLAN_LEVELS=()
YATTA_PLAN_MESSAGES=()

YATTA_PORT_PLAN_MODULES=()
YATTA_PORT_PLAN_PROTOCOLS=()
YATTA_PORT_PLAN_PORTS=()
YATTA_PORT_PLAN_PURPOSES=()

yatta_module_register() {
  YATTA_MODULE_IDS+=("$1")
  YATTA_MODULE_NAMES+=("$2")
  YATTA_MODULE_STAGES+=("$3")
  YATTA_MODULE_GROUPS+=("$4")
  YATTA_MODULE_RISKS+=("$5")
  YATTA_MODULE_RUNTIME_DEFAULTS+=("$6")
  YATTA_MODULE_LOCKED+=("$7")
  YATTA_MODULE_ENABLED+=("false")
  YATTA_MODULE_PROMPT_FNS+=("$8")
  YATTA_MODULE_PRE_APPLY_FNS+=("$9")
  YATTA_MODULE_APPLY_FNS+=("${10}")
  YATTA_MODULE_POST_APPLY_FNS+=("${11}")
}

yatta_module_selection_init() {
  local index risk runtime_default locked
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    risk="${YATTA_MODULE_RISKS[$index]}"
    runtime_default="${YATTA_MODULE_RUNTIME_DEFAULTS[$index]}"
    locked="${YATTA_MODULE_LOCKED[$index]}"
    if [[ "$locked" == "true" ]]; then
      YATTA_MODULE_ENABLED[$index]="true"
    elif [[ "$risk" == "high" ]]; then
      YATTA_MODULE_ENABLED[$index]="false"
    else
      YATTA_MODULE_ENABLED[$index]="$runtime_default"
    fi
  done
}

yatta_module_is_enabled() {
  local index="$1"
  [[ "${YATTA_MODULE_ENABLED[$index]}" == "true" ]]
}

yatta_module_selection_apply_list() {
  local raw_list="$1"
  local id wanted index
  IFS=',' read -ra wanted <<<"$raw_list"
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    if [[ "${YATTA_MODULE_LOCKED[$index]}" == "true" ]]; then
      YATTA_MODULE_ENABLED[$index]="true"
    else
      YATTA_MODULE_ENABLED[$index]="false"
    fi
  done
  for id in "${wanted[@]}"; do
    id="${id//[[:space:]]/}"
    [[ -z "$id" ]] && continue
    for index in "${!YATTA_MODULE_IDS[@]}"; do
      if [[ "${YATTA_MODULE_IDS[$index]}" == "$id" ]]; then
        YATTA_MODULE_ENABLED[$index]="true"
      fi
    done
  done
}

yatta_module_selection_show() {
  local index marker locked_label risk_label group_label
  printf '%s\n' "本次启用模块：" >&2
  printf '  %-4s %-4s %-14s %-12s %-8s %s\n' "序号" "启用" "阶段" "分组" "风险" "模块" >&2
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    marker="[ ]"
    yatta_module_is_enabled "$index" && marker="[x]"
    locked_label=""
    [[ "${YATTA_MODULE_LOCKED[$index]}" == "true" ]] && locked_label=" locked"
    risk_label="${YATTA_MODULE_RISKS[$index]}"
    group_label="${YATTA_MODULE_GROUPS[$index]}"
    printf '  %-4d %-4s %-14s %-12s %-8s %s%s\n' \
      "$((index + 1))" \
      "$marker" \
      "${YATTA_MODULE_STAGES[$index]}" \
      "$group_label" \
      "$risk_label" \
      "${YATTA_MODULE_NAMES[$index]}" \
      "$locked_label" >&2
  done
}

yatta_module_selection_prompt() {
  local answer index item
  local items=()
  while true; do
    yatta_module_selection_show
    printf '%s' "输入要切换启用状态的序号，多个序号用逗号分隔；直接回车继续: " >&2
    if yatta_has_tty; then
      IFS= read -r answer </dev/tty || answer=""
    else
      IFS= read -r answer || answer=""
    fi
    answer="${answer//$'\r'/}"
    [[ -z "$answer" ]] && return 0
    IFS=',' read -ra items <<<"$answer"
    for item in "${items[@]}"; do
      item="${item//[[:space:]]/}"
      if [[ ! "$item" =~ ^[0-9]+$ ]] || ((item < 1 || item > ${#YATTA_MODULE_IDS[@]})); then
        yatta_log_warn "忽略无效序号：${item}"
        continue
      fi
      index=$((item - 1))
      if [[ "${YATTA_MODULE_LOCKED[$index]}" == "true" ]]; then
        yatta_log_warn "模块 ${YATTA_MODULE_NAMES[$index]} 不可取消。"
        continue
      fi
      if yatta_module_is_enabled "$index"; then
        YATTA_MODULE_ENABLED[$index]="false"
      else
        YATTA_MODULE_ENABLED[$index]="true"
      fi
    done
  done
}

yatta_select_runtime_modules() {
  yatta_module_selection_init
  if [[ -n "${YATTA_TEST_MODULES:-}" ]]; then
    yatta_module_selection_apply_list "$YATTA_TEST_MODULES"
  fi
  yatta_ui_section "本次启用模块"
  if yatta_test_mode || ! yatta_has_tty; then
    yatta_module_selection_show
    return 0
  fi
  yatta_log_info "高风险模块默认不启用；locked 模块不可取消。"
  yatta_module_selection_prompt
}

yatta_version() {
  printf 'Yatta %s\n' "${YATTA_VERSION:-dev}"
}

yatta_handle_runtime_args() {
  if [[ "$#" -eq 0 ]]; then
    return 1
  fi
  if [[ "$#" -gt 1 ]]; then
    printf 'Yatta 只接受一个参数：--version。\n' >&2
    return 2
  fi
  case "$1" in
    -v | --version | version)
      yatta_version
      return 0
      ;;
    *)
      printf '未知参数：%s\n' "$1" >&2
      printf '可用参数：--version\n' >&2
      return 2
      ;;
  esac
}

yatta_plan_add() {
  local module="$1"
  local level="$2"
  local message="$3"
  YATTA_PLAN_MODULES+=("$module")
  YATTA_PLAN_LEVELS+=("$level")
  YATTA_PLAN_MESSAGES+=("$message")
}

yatta_plan_show() {
  local index total level_label
  total="${#YATTA_PLAN_MESSAGES[@]}"
  if [[ "$total" -eq 0 ]]; then
    yatta_log_warn "当前没有登记任何执行计划。"
    return 0
  fi

  printf '%s\n' "将执行以下 ${total} 项操作：" >&2
  for index in "${!YATTA_PLAN_MESSAGES[@]}"; do
    level_label="$(yatta_status_label "${YATTA_PLAN_LEVELS[$index]}")"
    printf '  %2d. [%s] %s: %s\n' \
      "$((index + 1))" \
      "$level_label" \
      "${YATTA_PLAN_MODULES[$index]}" \
      "${YATTA_PLAN_MESSAGES[$index]}" >&2
  done
}

yatta_port_plan_add() {
  local module="$1"
  local protocol="$2"
  local port="$3"
  local purpose="$4"
  protocol="${protocol,,}"
  if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
    yatta_log_warn "忽略不支持的端口协议：${protocol}"
    return 1
  fi
  if ! yatta_valid_port "$port"; then
    yatta_log_warn "忽略无效端口：${port}"
    return 1
  fi
  YATTA_PORT_PLAN_MODULES+=("$module")
  YATTA_PORT_PLAN_PROTOCOLS+=("$protocol")
  YATTA_PORT_PLAN_PORTS+=("$port")
  YATTA_PORT_PLAN_PURPOSES+=("$purpose")
}

yatta_port_plan_show() {
  local index total
  total="${#YATTA_PORT_PLAN_PORTS[@]}"
  if [[ "$total" -eq 0 ]]; then
    yatta_log_info "当前没有登记额外端口放行需求。"
    return 0
  fi
  printf '已登记以下端口放行需求：\n' >&2
  printf '  %-12s %-8s %-8s %s\n' "来源模块" "协议" "端口" "用途" >&2
  for index in "${!YATTA_PORT_PLAN_PORTS[@]}"; do
    printf '  %-12s %-8s %-8s %s\n' \
      "${YATTA_PORT_PLAN_MODULES[$index]}" \
      "${YATTA_PORT_PLAN_PROTOCOLS[$index]}" \
      "${YATTA_PORT_PLAN_PORTS[$index]}" \
      "${YATTA_PORT_PLAN_PURPOSES[$index]}" >&2
  done
}

yatta_call_function() {
  local fn="$1"
  if ! declare -F "$fn" >/dev/null 2>&1; then
    yatta_log_error "缺少函数：${fn}"
    return 1
  fi
  "$fn"
}

yatta_has_tty() {
  [[ -t 0 && -r /dev/tty && -w /dev/tty ]]
}

yatta_test_mode() {
  [[ "${YATTA_TEST_MODE:-}" == "1" ]]
}

yatta_dry_run() {
  [[ "${YATTA_DRY_RUN:-}" == "1" ]]
}

yatta_string_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

# ===== runtime/core/main.sh =====
# 这里是生成脚本的主流程入口。它只负责把启动检查、模块 prompt、
# 执行计划确认和 apply 顺序串起来；具体 UI、系统探测和 Ubuntu 命令封装
# 分别放在 runtime/ui、runtime/system 和 runtime/adapter 中。

yatta_run_prompts() {
  local index id name prompt_fn
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    id="${YATTA_MODULE_IDS[$index]}"
    name="${YATTA_MODULE_NAMES[$index]}"
    prompt_fn="${YATTA_MODULE_PROMPT_FNS[$index]}"
    if ! yatta_module_is_enabled "$index"; then
      yatta_log_info "跳过未启用模块：${name}"
      continue
    fi
    yatta_ui_section "收集配置：${name}"
    if ! yatta_call_function "$prompt_fn"; then
      yatta_log_error "模块 ${id} 的询问阶段失败。"
      return 1
    fi
  done
}

yatta_run_applies() {
  local phase="$1"
  local phase_name="$2"
  local index id name apply_fn
  yatta_ui_section "$phase_name"
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    id="${YATTA_MODULE_IDS[$index]}"
    name="${YATTA_MODULE_NAMES[$index]}"
    if ! yatta_module_is_enabled "$index"; then
      yatta_log_info "跳过未启用模块：${name}"
      continue
    fi
    case "$phase" in
      pre) apply_fn="${YATTA_MODULE_PRE_APPLY_FNS[$index]}" ;;
      post) apply_fn="${YATTA_MODULE_POST_APPLY_FNS[$index]}" ;;
      *) apply_fn="${YATTA_MODULE_APPLY_FNS[$index]}" ;;
    esac
    if [[ "$phase" == "main" && "$id" == "user" ]]; then
      yatta_log_info "执行 ${name}"
      yatta_call_function "$apply_fn"
    else
      yatta_ui_spinner "执行 ${phase_name}：${name}" yatta_call_function "$apply_fn"
    fi
    if [[ "$?" -ne 0 ]]; then
      yatta_log_error "模块 ${id} 的 ${phase_name} 失败，后续任务已停止。"
      return 1
    fi
    yatta_log_ok "模块 ${name} 的 ${phase_name} 已完成。"
  done
}

yatta_main() {
  local apply_default="n"
  local arg_status
  yatta_handle_runtime_args "$@"
  arg_status="$?"
  if [[ "$arg_status" -eq 0 ]]; then
    return 0
  fi
  if [[ "$arg_status" -ne 1 ]]; then
    return 1
  fi

  yatta_ui_init
  yatta_ui_brand
  yatta_preflight || return 1

  if ! declare -F yatta_register_generated_modules >/dev/null 2>&1; then
    yatta_log_error "生成脚本缺少模块注册函数。"
    return 1
  fi
  yatta_register_generated_modules
  yatta_select_runtime_modules

  yatta_ui_section "配置收集"
  yatta_run_prompts || return 1

  yatta_ui_section "执行计划"
  yatta_plan_show
  if yatta_test_mode && yatta_dry_run; then
    apply_default="${YATTA_TEST_CONFIRM_APPLY:-y}"
  fi
  if ! yatta_ui_confirm "确认后才会开始修改系统。现在执行计划吗？" "$apply_default"; then
    yatta_log_warn "已取消执行，没有修改系统。"
    return 0
  fi

  if ! yatta_run_applies "pre" "前置执行"; then
    yatta_log_error "Yatta 前置执行失败，请根据上方日志处理后重试。"
    return 1
  fi
  if ! yatta_run_applies "main" "模块执行"; then
    yatta_log_error "Yatta 执行失败，请根据上方日志处理后重试。"
    return 1
  fi
  if ! yatta_run_applies "post" "收尾执行"; then
    yatta_log_error "Yatta 收尾执行失败，请根据上方日志处理后重试。"
    return 1
  fi

  yatta_ui_section "结果摘要"
  yatta_log_ok "Yatta 已完成本次执行。"
}

# ===== runtime/ui/display.sh =====
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

# ===== runtime/system/checks.sh =====
# 这里集中处理脚本入口硬检查和环境摘要。runtime 负责阻断 v1 明确
# 不支持的环境；system-check 模块只调用这些探测函数来展示更完整的状态。

yatta_command_exists() {
  if yatta_test_mode; then
    return 0
  fi
  command -v "$1" >/dev/null 2>&1
}

yatta_is_root() {
  if yatta_test_mode; then
    [[ "${YATTA_TEST_ROOT_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

yatta_is_ubuntu() {
  if yatta_test_mode; then
    [[ "${YATTA_TEST_UBUNTU_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]]
}

yatta_ubuntu_version() {
  if yatta_test_mode; then
    printf '%s\n' "Ubuntu test-mode"
    return 0
  fi
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf '%s\n' "${PRETTY_NAME:-Ubuntu}"
    return 0
  fi
  printf '%s\n' "未知"
}

yatta_bash_version() {
  printf '%s\n' "${BASH_VERSION:-unknown}"
}

yatta_systemd_available() {
  if yatta_test_mode; then
    return 0
  fi
  yatta_command_exists systemctl && [[ -d /run/systemd/system ]]
}

yatta_apt_available() {
  yatta_command_exists apt-get && yatta_command_exists apt
}

yatta_network_status() {
  if yatta_test_mode; then
    [[ "${YATTA_TEST_NETWORK_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  if yatta_command_exists getent && getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    return 0
  fi
  if yatta_command_exists ping && ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

yatta_current_hostname() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_HOSTNAME:-yatta-test-host}"
    return 0
  fi
  hostname
}

yatta_valid_hostname() {
  local hostname="$1"
  local label
  local labels
  [[ -n "$hostname" && "${#hostname}" -le 253 ]] || return 1
  [[ "$hostname" != .* && "$hostname" != *. && "$hostname" != *..* ]] || return 1
  IFS='.' read -r -a labels <<<"$hostname"
  for label in "${labels[@]}"; do
    [[ -n "$label" && "${#label}" -le 63 ]] || return 1
    [[ "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
  done
}

yatta_valid_username() {
  local username="$1"
  [[ "$username" != "root" ]] || return 1
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

yatta_current_timezone() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_TIMEZONE:-UTC}"
    return 0
  fi
  if yatta_command_exists timedatectl; then
    timedatectl show -p Timezone --value 2>/dev/null && return 0
  fi
  if [[ -r /etc/timezone ]]; then
    head -n 1 /etc/timezone
    return 0
  fi
  printf '%s\n' "未知"
}

yatta_timezone_available() {
  local timezone="$1"
  if [[ -z "$timezone" || "$timezone" == /* || "$timezone" == *..* ]]; then
    return 1
  fi
  if yatta_test_mode; then
    [[ "${YATTA_TEST_TIMEZONE_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  if [[ -f "/usr/share/zoneinfo/${timezone}" ]]; then
    return 0
  fi
  yatta_command_exists timedatectl && timedatectl list-timezones 2>/dev/null | grep -Fx -- "$timezone" >/dev/null
}

yatta_user_exists() {
  local username="$1"
  if yatta_test_mode; then
    [[ " ${YATTA_TEST_EXISTING_USERS:-root} " == *" ${username} "* ]]
    return $?
  fi
  getent passwd "$username" >/dev/null 2>&1
}

yatta_user_in_group() {
  local username="$1"
  local group="$2"
  if yatta_test_mode; then
    [[ "$group" == "sudo" && " ${YATTA_TEST_SUDO_USERS:-root} " == *" ${username} "* ]]
    return $?
  fi
  id -nG "$username" 2>/dev/null | tr ' ' '\n' | grep -Fx -- "$group" >/dev/null
}

yatta_user_home() {
  local username="$1"
  if yatta_test_mode; then
    printf '/home/%s\n' "$username"
    return 0
  fi
  getent passwd "$username" | awk -F: '{ print $6; exit }'
}

yatta_list_normal_users() {
  if yatta_test_mode; then
    printf '%s\n' ${YATTA_TEST_NORMAL_USERS:-}
    return 0
  fi
  awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" { print $1 }' /etc/passwd
}

yatta_user_is_protected() {
  local username="$1"
  [[ -z "$username" ]] && return 0
  [[ "$username" == "root" ]] && return 0
  [[ -n "${YATTA_USER_NAME:-}" && "$username" == "$YATTA_USER_NAME" ]] && return 0
  [[ -n "${SUDO_USER:-}" && "$username" == "$SUDO_USER" ]] && return 0
  return 1
}

yatta_valid_ssh_public_key() {
  local key="$1"
  [[ "$key" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]]
}

yatta_package_installed() {
  local package="$1"
  if yatta_test_mode; then
    [[ " ${YATTA_TEST_INSTALLED_PACKAGES:-} " == *" ${package} "* ]]
    return $?
  fi
  dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fx "install ok installed" >/dev/null
}

yatta_missing_packages() {
  local package
  for package in "$@"; do
    if ! yatta_package_installed "$package"; then
      printf '%s\n' "$package"
    fi
  done
}

yatta_current_swap_bytes() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_SWAP_BYTES:-0}"
    return 0
  fi
  awk 'NR > 1 { total += $3 } END { printf "%.0f\n", total * 1024 }' /proc/swaps 2>/dev/null
}

yatta_memory_total_mb() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_MEMORY_MB:-2048}"
    return 0
  fi
  awk '/^MemTotal:/ { printf "%d\n", int($2 / 1024); exit }' /proc/meminfo 2>/dev/null
}

yatta_root_available_mb() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_ROOT_AVAILABLE_MB:-8192}"
    return 0
  fi
  df -Pm / 2>/dev/null | awk 'NR == 2 { print $4; exit }'
}

yatta_recommended_swap_mb() {
  local memory_mb="$1"
  local recommended
  if [[ ! "$memory_mb" =~ ^[0-9]+$ ]] || ((memory_mb <= 0)); then
    printf '%s\n' "1024"
    return 0
  fi
  recommended=$((memory_mb / 2))
  ((recommended < 1024)) && recommended=1024
  ((recommended > 4096)) && recommended=4096
  printf '%s\n' "$recommended"
}

yatta_valid_swap_size_mb() {
  local size_mb="$1"
  [[ "$size_mb" =~ ^[0-9]+$ ]] && ((size_mb >= 256 && size_mb <= 32768))
}

yatta_valid_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535))
}

yatta_detect_ssh_port() {
  local files=("/etc/ssh/sshd_config")
  local conf
  local detected
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_SSH_PORT:-22}"
    return 0
  fi
  if yatta_command_exists sshd; then
    detected="$(sshd -T 2>/dev/null | awk '$1 == "port" && $2 ~ /^[0-9]+$/ { print $2; exit }')"
    if [[ -n "$detected" ]]; then
      printf '%s\n' "$detected"
      return 0
    fi
  fi
  if [[ -d /etc/ssh/sshd_config.d ]]; then
    for conf in /etc/ssh/sshd_config.d/*.conf; do
      [[ -e "$conf" ]] && files+=("$conf")
    done
  fi
  awk '
    {
      sub(/[[:space:]]*#.*/, "")
      if (tolower($1) == "port" && $2 ~ /^[0-9]+$/) {
        print $2
        exit
      }
    }
  ' "${files[@]}" 2>/dev/null | {
    IFS= read -r detected || detected=""
    if [[ -n "$detected" ]]; then
      printf '%s\n' "$detected"
    else
      printf '%s\n' "22"
    fi
  }
}

yatta_preflight() {
  if [[ -z "${BASH_VERSION:-}" ]]; then
    printf '%s\n' "Yatta 必须使用 Bash 运行，请执行：sudo bash yatta.sh" >&2
    return 1
  fi
  if ! yatta_is_root; then
    yatta_log_error "Yatta v1 必须以 root 身份运行。请执行：sudo bash yatta.sh"
    return 1
  fi
  if ! yatta_is_ubuntu; then
    yatta_log_error "Yatta v1 只支持 Ubuntu。当前系统不是受支持的 Ubuntu 环境。"
    return 1
  fi
  if ! yatta_apt_available; then
    yatta_log_error "缺少 apt/apt-get，无法按 Ubuntu 服务器初始化流程继续。"
    return 1
  fi
  if ! yatta_systemd_available; then
    yatta_log_error "未检测到可用 systemd，v1 需要 systemd 环境。"
    return 1
  fi
  yatta_log_ok "入口检查通过。"
}

yatta_system_summary() {
  if yatta_is_ubuntu; then
    printf 'Ubuntu\tok\t%s\n' "$(yatta_ubuntu_version)"
  else
    printf 'Ubuntu\terror\tv1 只支持 Ubuntu\n'
  fi

  if yatta_is_root; then
    printf 'root\tok\t当前以 root 身份运行\n'
  else
    printf 'root\terror\t请使用 sudo bash yatta.sh\n'
  fi

  if [[ -n "${BASH_VERSION:-}" ]]; then
    printf 'Bash\tok\t%s\n' "$(yatta_bash_version)"
  else
    printf 'Bash\terror\t需要 Bash 运行环境\n'
  fi

  if yatta_apt_available; then
    printf 'apt\tok\tapt 与 apt-get 可用\n'
  else
    printf 'apt\terror\t缺少 apt 或 apt-get\n'
  fi

  if yatta_systemd_available; then
    printf 'systemd\tok\tsystemctl 与运行目录可用\n'
  else
    printf 'systemd\terror\t未检测到可用 systemd\n'
  fi

  if yatta_network_status; then
    printf 'network\tok\t基础网络解析或连通性可用\n'
  else
    printf 'network\twarn\t暂未确认网络连通性，后续 apt 操作可能失败\n'
  fi
}

# ===== runtime/adapter/ubuntu.sh =====
# 这里封装跨模块复用或平台差异明显的 Ubuntu 系统修改命令。
# 模块私有的一次性流程可以留在模块内，但仍应复用 yatta_run_command
# 获得一致的 dry-run 行为。

yatta_command_preview() {
  local part
  for part in "$@"; do
    printf '%q ' "$part"
  done
}

yatta_run_command() {
  if yatta_dry_run; then
    yatta_log_info "[dry-run] $(yatta_command_preview "$@")"
    return 0
  fi
  "$@"
}

yatta_apt_update() {
  yatta_run_command apt-get update
}

yatta_apt_install() {
  yatta_run_command apt-get install -y "$@"
}

yatta_apt_upgrade() {
  yatta_run_command apt-get upgrade -y
}

yatta_apt_install_missing() {
  local packages=("$@")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    yatta_log_ok "没有缺失的软件包需要安装。"
    return 0
  fi
  yatta_apt_install "${packages[@]}"
}

yatta_ensure_package_installed() {
  local package="$1"
  if yatta_package_installed "$package"; then
    yatta_log_ok "软件包已安装：${package}"
    return 0
  fi
  yatta_apt_update || return 1
  yatta_apt_install "$package"
}

yatta_ufw_default_deny_incoming() {
  yatta_run_command ufw default deny incoming
}

yatta_ufw_default_allow_outgoing() {
  yatta_run_command ufw default allow outgoing
}

yatta_ufw_allow_port() {
  local port="$1"
  local proto="${2:-tcp}"
  yatta_run_command ufw allow "${port}/${proto}"
}

yatta_ufw_enable() {
  yatta_run_command ufw --force enable
}

yatta_set_timezone() {
  local timezone="$1"
  yatta_run_command timedatectl set-timezone "$timezone"
}

yatta_set_hostname() {
  local hostname="$1"
  yatta_run_command hostnamectl set-hostname "$hostname"
}

yatta_add_sudo_user() {
  local username="$1"
  yatta_run_command adduser "$username" || return 1
  yatta_ensure_sudo_group "$username"
}

yatta_ensure_sudo_group() {
  local username="$1"
  if yatta_user_in_group "$username" "sudo"; then
    yatta_log_ok "用户 ${username} 已在 sudo 组中。"
    return 0
  fi
  yatta_run_command usermod -aG sudo "$username"
}

yatta_ensure_sudo_nopasswd() {
  local username="$1"
  local target="/etc/sudoers.d/yatta-${username}"
  local content="${username} ALL=(ALL) NOPASSWD:ALL"$'\n'
  local tmp
  if [[ -f "$target" ]] && [[ "$(cat "$target")" == "$content" ]]; then
    yatta_log_ok "sudo 免密配置已是期望内容：${target}"
    return 0
  fi
  if yatta_dry_run; then
    yatta_log_info "[dry-run] write validated sudoers drop-in ${target}"
    return 0
  fi
  if ! yatta_command_exists visudo; then
    yatta_log_error "缺少 visudo，无法安全写入 sudoers 配置。"
    return 1
  fi
  tmp="$(mktemp)" || return 1
  printf '%s' "$content" >"$tmp"
  chmod 0440 "$tmp"
  if ! visudo -cf "$tmp" >/dev/null; then
    rm -f "$tmp"
    yatta_log_error "sudoers drop-in 校验失败，未写入免密配置。"
    return 1
  fi
  install -m 0440 "$tmp" "$target"
  rm -f "$tmp"
}

yatta_ensure_authorized_keys() {
  local username="$1"
  shift
  local home ssh_dir auth_file key
  home="$(yatta_user_home "$username")"
  if [[ -z "$home" ]]; then
    yatta_log_error "无法确定用户 ${username} 的 home 目录。"
    return 1
  fi
  ssh_dir="${home}/.ssh"
  auth_file="${ssh_dir}/authorized_keys"
  if yatta_dry_run; then
    yatta_log_info "[dry-run] ensure ${auth_file} with $# SSH public key(s)"
    return 0
  fi
  install -d -m 0700 -o "$username" -g "$username" "$ssh_dir" || return 1
  touch "$auth_file" || return 1
  chown "$username:$username" "$auth_file" || return 1
  chmod 0600 "$auth_file" || return 1
  for key in "$@"; do
    if grep -Fx -- "$key" "$auth_file" >/dev/null 2>&1; then
      continue
    fi
    printf '%s\n' "$key" >>"$auth_file"
  done
}

yatta_delete_user_keep_home() {
  local username="$1"
  if yatta_user_is_protected "$username"; then
    yatta_log_error "拒绝删除受保护用户：${username}"
    return 1
  fi
  if ! yatta_user_exists "$username"; then
    yatta_log_ok "用户 ${username} 不存在，跳过删除。"
    return 0
  fi
  if yatta_command_exists deluser; then
    yatta_run_command deluser "$username"
  else
    yatta_run_command userdel "$username"
  fi
}

yatta_backup_file() {
  local path="$1"
  local backup
  [[ -f "$path" ]] || return 0
  backup="${path}.yatta.bak.$(date +%Y%m%d%H%M%S)"
  yatta_run_command cp -a "$path" "$backup"
}

yatta_write_file_if_changed() {
  local path="$1"
  local content="$2"
  if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$content" ]]; then
    yatta_log_ok "文件已是期望内容：${path}"
    return 0
  fi
  if yatta_dry_run; then
    yatta_log_info "[dry-run] write ${path}"
    return 0
  fi
  printf '%s' "$content" >"$path"
}

yatta_module_system_check_prompt() {
# system-check 在 Phase 2 负责展示环境摘要，并把前置检查登记到执行计划。
# 入口硬阻断仍由 runtime/system 完成，这里只复用探测函数，不重复散落检查逻辑。
printf '%-12s %-8s %s\n' "项目" "状态" "说明" >&2
printf '%-12s %-8s %s\n' "------------" "--------" "------------------------------" >&2
while IFS=$'\t' read -r item status detail; do
  printf '%-12s %-8s %s\n' "$item" "$status" "$detail" >&2
  yatta_plan_add "system-check" "$status" "检查 ${item}：${detail}"
done < <(yatta_system_summary)
}

yatta_module_system_check_pre_apply() {
  return 0
}

yatta_module_system_check_apply() {
# apply 阶段只做执行前最终确认，复用 runtime/system 的硬检查边界。
# 网络检查失败只提示风险，不阻断后续不依赖网络的模块。
yatta_preflight || return 1
if yatta_network_status; then
  yatta_log_ok "基础网络状态可用。"
else
  yatta_log_warn "暂未确认网络连通性，后续需要 apt 的模块可能失败。"
fi
}

yatta_module_system_check_post_apply() {
  return 0
}

yatta_module_hostname_prompt() {
# hostname 模块只在询问阶段读取当前主机名并保存用户选择，真正修改留给 apply。
YATTA_HOSTNAME_CURRENT="$(yatta_current_hostname)"
YATTA_HOSTNAME_ACTION="keep"
YATTA_HOSTNAME_TARGET="$YATTA_HOSTNAME_CURRENT"

choice="$(yatta_ui_select "主机名设置" 0 "保留当前主机名：${YATTA_HOSTNAME_CURRENT}" "设置新的主机名")"
case "$choice" in
  设置新的主机名)
    while true; do
      YATTA_HOSTNAME_TARGET="$(yatta_ui_input "新的主机名" "$YATTA_HOSTNAME_CURRENT")"
      if yatta_valid_hostname "$YATTA_HOSTNAME_TARGET"; then
        YATTA_HOSTNAME_ACTION="set"
        break
      fi
      yatta_log_warn "主机名只能包含字母、数字、短横线和点，且每段不能以短横线开头或结尾。"
    done
    ;;
esac

if [[ "$YATTA_HOSTNAME_ACTION" == "keep" ]]; then
  yatta_plan_add "hostname" "ok" "保留当前主机名：${YATTA_HOSTNAME_CURRENT}"
elif [[ "$YATTA_HOSTNAME_TARGET" == "$YATTA_HOSTNAME_CURRENT" ]]; then
  yatta_plan_add "hostname" "ok" "目标主机名已是当前值：${YATTA_HOSTNAME_TARGET}"
else
  yatta_plan_add "hostname" "info" "将主机名设置为：${YATTA_HOSTNAME_TARGET}"
fi
}

yatta_module_hostname_pre_apply() {
  return 0
}

yatta_module_hostname_apply() {
# apply 阶段重新检查当前值，避免重复运行时执行不必要的 hostnamectl。
if [[ "${YATTA_HOSTNAME_ACTION:-keep}" == "keep" ]]; then
  yatta_log_ok "保留当前主机名。"
  return 0
fi

if ! yatta_valid_hostname "${YATTA_HOSTNAME_TARGET:-}"; then
  yatta_log_error "目标主机名无效，已停止。"
  return 1
fi

current="$(yatta_current_hostname)"
if [[ "$current" == "$YATTA_HOSTNAME_TARGET" ]]; then
  yatta_log_ok "主机名已是期望值：${YATTA_HOSTNAME_TARGET}"
  return 0
fi

yatta_set_hostname "$YATTA_HOSTNAME_TARGET"
}

yatta_module_hostname_post_apply() {
  return 0
}

yatta_module_timezone_prompt() {
# timezone 模块只保存时区选择，实际 timedatectl 修改在 apply 阶段完成。
YATTA_TIMEZONE_CURRENT="$(yatta_current_timezone)"
YATTA_TIMEZONE_ACTION="set"
YATTA_TIMEZONE_TARGET="Asia/Shanghai"

choice="$(yatta_ui_select "时区设置" 0 "设置为 Asia/Shanghai" "输入其他时区" "跳过时区设置")"
case "$choice" in
  输入其他时区)
    while true; do
      YATTA_TIMEZONE_TARGET="$(yatta_ui_input "时区名称" "$YATTA_TIMEZONE_CURRENT")"
      if yatta_timezone_available "$YATTA_TIMEZONE_TARGET"; then
        break
      fi
      yatta_log_warn "未找到该时区，请使用类似 Asia/Shanghai 的 IANA 时区名称。"
    done
    ;;
  跳过时区设置)
    YATTA_TIMEZONE_ACTION="skip"
    ;;
esac

if [[ "$YATTA_TIMEZONE_ACTION" == "skip" ]]; then
  yatta_plan_add "timezone" "ok" "跳过时区设置，当前时区：${YATTA_TIMEZONE_CURRENT}"
elif [[ "$YATTA_TIMEZONE_TARGET" == "$YATTA_TIMEZONE_CURRENT" ]]; then
  yatta_plan_add "timezone" "ok" "时区已是期望值：${YATTA_TIMEZONE_TARGET}"
else
  yatta_plan_add "timezone" "info" "将时区设置为：${YATTA_TIMEZONE_TARGET}"
fi
}

yatta_module_timezone_pre_apply() {
  return 0
}

yatta_module_timezone_apply() {
# apply 阶段重新检查当前时区，重复运行时尽量不做无意义修改。
if [[ "${YATTA_TIMEZONE_ACTION:-skip}" == "skip" ]]; then
  yatta_log_ok "已跳过时区设置。"
  return 0
fi

if ! yatta_timezone_available "${YATTA_TIMEZONE_TARGET:-}"; then
  yatta_log_error "目标时区不可用，已停止。"
  return 1
fi

current="$(yatta_current_timezone)"
if [[ "$current" == "$YATTA_TIMEZONE_TARGET" ]]; then
  yatta_log_ok "时区已是期望值：${YATTA_TIMEZONE_TARGET}"
  return 0
fi

yatta_set_timezone "$YATTA_TIMEZONE_TARGET"
}

yatta_module_timezone_post_apply() {
  return 0
}

yatta_module_swap_prompt() {
# swap 模块只规划单个 swapfile。已有 swap 时默认不动，避免覆盖用户已有策略。
YATTA_SWAP_ACTION="skip"
YATTA_SWAP_PATH="/swapfile"
YATTA_SWAP_SIZE_MB="0"

YATTA_SWAP_CURRENT_BYTES="$(yatta_current_swap_bytes)"
YATTA_SWAP_MEMORY_MB="$(yatta_memory_total_mb)"
YATTA_SWAP_ROOT_AVAILABLE_MB="$(yatta_root_available_mb)"
YATTA_SWAP_RECOMMENDED_MB="$(yatta_recommended_swap_mb "$YATTA_SWAP_MEMORY_MB")"

if [[ "$YATTA_SWAP_CURRENT_BYTES" =~ ^[0-9]+$ ]] && ((YATTA_SWAP_CURRENT_BYTES > 0)); then
  yatta_plan_add "swap" "ok" "检测到系统已有 swap，跳过创建。"
else
  yatta_log_info "当前未检测到 swap；内存约 ${YATTA_SWAP_MEMORY_MB} MB，根分区可用约 ${YATTA_SWAP_ROOT_AVAILABLE_MB} MB。"
  choice="$(yatta_ui_select "swap 设置" 0 "创建推荐大小：${YATTA_SWAP_RECOMMENDED_MB} MB" "输入自定义大小" "跳过 swap 设置")"
  case "$choice" in
    创建推荐大小*)
      YATTA_SWAP_ACTION="create"
      YATTA_SWAP_SIZE_MB="$YATTA_SWAP_RECOMMENDED_MB"
      ;;
    输入自定义大小)
      while true; do
        YATTA_SWAP_SIZE_MB="$(yatta_ui_input "swap 大小（MB，256-32768）" "$YATTA_SWAP_RECOMMENDED_MB")"
        if yatta_valid_swap_size_mb "$YATTA_SWAP_SIZE_MB"; then
          YATTA_SWAP_ACTION="create"
          break
        fi
        yatta_log_warn "swap 大小必须是 256 到 32768 之间的整数 MB。"
      done
      ;;
  esac

  if [[ "$YATTA_SWAP_ACTION" == "create" ]]; then
    if [[ "$YATTA_SWAP_ROOT_AVAILABLE_MB" =~ ^[0-9]+$ ]] && ((YATTA_SWAP_ROOT_AVAILABLE_MB <= YATTA_SWAP_SIZE_MB + 256)); then
      yatta_log_warn "根分区可用空间不足以安全创建该 swapfile，已跳过。"
      YATTA_SWAP_ACTION="skip"
    fi
  fi

  if [[ "$YATTA_SWAP_ACTION" == "create" ]]; then
    yatta_plan_add "swap" "info" "将创建 ${YATTA_SWAP_PATH}，大小 ${YATTA_SWAP_SIZE_MB} MB，并写入 /etc/fstab。"
  else
    yatta_plan_add "swap" "info" "跳过 swap 设置。"
  fi
fi
}

yatta_module_swap_pre_apply() {
  return 0
}

yatta_module_swap_apply() {
# apply 阶段重新检查 swap 状态，避免重复创建或覆盖已有策略。
if [[ "${YATTA_SWAP_ACTION:-skip}" != "create" ]]; then
  yatta_log_info "已跳过 swap 设置。"
  return 0
fi

if ! yatta_valid_swap_size_mb "${YATTA_SWAP_SIZE_MB:-}"; then
  yatta_log_error "swap 大小无效，已停止。"
  return 1
fi

current_swap_bytes="$(yatta_current_swap_bytes)"
if [[ "$current_swap_bytes" =~ ^[0-9]+$ ]] && ((current_swap_bytes > 0)); then
  yatta_log_ok "系统已存在 swap，跳过创建。"
  return 0
fi

available_mb="$(yatta_root_available_mb)"
if [[ "$available_mb" =~ ^[0-9]+$ ]] && ((available_mb <= YATTA_SWAP_SIZE_MB + 256)); then
  yatta_log_error "根分区可用空间不足，无法安全创建 ${YATTA_SWAP_SIZE_MB} MB swapfile。"
  return 1
fi

swap_path="${YATTA_SWAP_PATH:-/swapfile}"
fstab_line="${swap_path} none swap sw 0 0"

if swapon --show=NAME --noheadings 2>/dev/null | grep -Fx -- "$swap_path" >/dev/null; then
  yatta_log_ok "swapfile 已启用：${swap_path}"
else
  if [[ -e "$swap_path" ]]; then
    yatta_log_warn "swapfile 路径已存在，将尝试直接启用：${swap_path}"
  elif yatta_command_exists fallocate; then
    yatta_run_command fallocate -l "${YATTA_SWAP_SIZE_MB}M" "$swap_path" || return 1
  else
    yatta_run_command dd if=/dev/zero of="$swap_path" bs=1M count="$YATTA_SWAP_SIZE_MB" status=progress || return 1
  fi

  yatta_run_command chmod 0600 "$swap_path" || return 1
  yatta_run_command mkswap "$swap_path" || return 1
  yatta_run_command swapon "$swap_path" || return 1
fi

if [[ -r /etc/fstab ]] && grep -Fx -- "$fstab_line" /etc/fstab >/dev/null 2>&1; then
  yatta_log_ok "fstab 已包含 swapfile 配置。"
elif yatta_dry_run; then
  yatta_log_info "[dry-run] append to /etc/fstab: ${fstab_line}"
else
  printf '%s\n' "$fstab_line" >>/etc/fstab
fi
}

yatta_module_swap_post_apply() {
  return 0
}

yatta_module_user_prompt() {
# user 模块只收集账户初始化意图。密码交给 adduser，SSH 服务安全策略交给后续 ssh-hardening。
YATTA_USER_ACTION="skip"
YATTA_USER_NAME=""
YATTA_USER_SUDO_NOPASSWD="0"
YATTA_USER_IMPORT_KEYS="0"
YATTA_USER_SSH_KEYS=()
YATTA_USER_DELETE_USERS=()

if yatta_ui_confirm "是否创建或确认一个非 root sudo 用户？" "y"; then
  default_user="${SUDO_USER:-deploy}"
  [[ "$default_user" == "root" ]] && default_user="deploy"
  while true; do
    YATTA_USER_NAME="$(yatta_ui_input "sudo 用户名" "$default_user")"
    if yatta_valid_username "$YATTA_USER_NAME"; then
      YATTA_USER_ACTION="ensure"
      break
    fi
    yatta_log_warn "用户名需以小写字母或下划线开头，只包含小写字母、数字、下划线或短横线，最长 32 个字符，且不能是 root。"
  done

  if yatta_ui_confirm "是否为 ${YATTA_USER_NAME} 设置 sudo 免密？" "n"; then
    YATTA_USER_SUDO_NOPASSWD="1"
  fi

  if yatta_ui_confirm "是否向 ${YATTA_USER_NAME} 导入 SSH 公钥？" "n"; then
    while IFS= read -r key_line; do
      key_line="$(yatta_string_trim "$key_line")"
      [[ -z "$key_line" ]] && continue
      if ! yatta_valid_ssh_public_key "$key_line"; then
        yatta_log_warn "忽略格式不像 OpenSSH 公钥的输入。"
        continue
      fi
      duplicate="0"
      for existing_key in "${YATTA_USER_SSH_KEYS[@]}"; do
        [[ "$existing_key" == "$key_line" ]] && duplicate="1"
      done
      [[ "$duplicate" == "1" ]] && continue
      YATTA_USER_SSH_KEYS+=("$key_line")
    done < <(yatta_ui_multiline_input "请粘贴 SSH 公钥，每行一个。")
    if [[ "${#YATTA_USER_SSH_KEYS[@]}" -gt 0 ]]; then
      YATTA_USER_IMPORT_KEYS="1"
    else
      yatta_log_warn "没有收到可导入的有效 SSH 公钥。"
    fi
  fi

  candidate_users=()
  while IFS= read -r candidate_user; do
    candidate_user="$(yatta_string_trim "$candidate_user")"
    [[ -z "$candidate_user" ]] && continue
    yatta_user_is_protected "$candidate_user" && continue
    candidate_users+=("$candidate_user")
  done < <(yatta_list_normal_users)

  if [[ "${#candidate_users[@]}" -gt 0 ]]; then
    yatta_log_info "可检查的普通用户：${candidate_users[*]}"
    if yatta_ui_confirm "是否逐个确认删除多余普通用户？默认保留 home。" "n"; then
      for candidate_user in "${candidate_users[@]}"; do
        if yatta_ui_confirm "确认删除用户 ${candidate_user}？" "n"; then
          YATTA_USER_DELETE_USERS+=("$candidate_user")
        fi
      done
    fi
  fi
fi

if [[ "$YATTA_USER_ACTION" == "skip" ]]; then
  yatta_plan_add "user" "warn" "跳过非 root sudo 用户创建。"
else
  if yatta_user_exists "$YATTA_USER_NAME"; then
    if yatta_user_in_group "$YATTA_USER_NAME" "sudo"; then
      yatta_plan_add "user" "ok" "用户 ${YATTA_USER_NAME} 已存在且已在 sudo 组。"
    else
      yatta_plan_add "user" "info" "用户 ${YATTA_USER_NAME} 已存在，将加入 sudo 组。"
    fi
  else
    yatta_plan_add "user" "info" "将创建非 root sudo 用户 ${YATTA_USER_NAME}；密码由 adduser 在执行阶段处理。"
  fi

  if [[ "$YATTA_USER_SUDO_NOPASSWD" == "1" ]]; then
    yatta_plan_add "user" "warn" "将为 ${YATTA_USER_NAME} 写入独立 sudo 免密配置。"
  else
    yatta_plan_add "user" "info" "不设置 sudo 免密。"
  fi

  if [[ "$YATTA_USER_IMPORT_KEYS" == "1" ]]; then
    yatta_plan_add "user" "info" "将向 ${YATTA_USER_NAME} 导入 ${#YATTA_USER_SSH_KEYS[@]} 个 SSH 公钥。"
  else
    yatta_plan_add "user" "info" "不导入 SSH 公钥。"
  fi

  if [[ "${#YATTA_USER_DELETE_USERS[@]}" -gt 0 ]]; then
    yatta_plan_add "user" "warn" "将删除普通用户（保留 home）：${YATTA_USER_DELETE_USERS[*]}"
  else
    yatta_plan_add "user" "info" "不删除其他普通用户。"
  fi
fi
}

yatta_module_user_pre_apply() {
  return 0
}

yatta_module_user_apply() {
# apply 阶段才调用系统账户工具。所有危险动作都按 prompt 阶段的明确确认执行。
if [[ "${YATTA_USER_ACTION:-skip}" == "skip" ]]; then
  yatta_log_warn "已跳过非 root sudo 用户创建。"
  return 0
fi

if ! yatta_valid_username "${YATTA_USER_NAME:-}"; then
  yatta_log_error "sudo 用户名无效，已停止。"
  return 1
fi

if yatta_user_exists "$YATTA_USER_NAME"; then
  yatta_log_info "用户 ${YATTA_USER_NAME} 已存在。"
  yatta_ensure_sudo_group "$YATTA_USER_NAME" || return 1
else
  yatta_add_sudo_user "$YATTA_USER_NAME" || return 1
fi

if [[ "${YATTA_USER_SUDO_NOPASSWD:-0}" == "1" ]]; then
  yatta_ensure_sudo_nopasswd "$YATTA_USER_NAME" || return 1
fi

if [[ "${YATTA_USER_IMPORT_KEYS:-0}" == "1" ]]; then
  if [[ "${#YATTA_USER_SSH_KEYS[@]}" -eq 0 ]]; then
    yatta_log_warn "未找到可导入的 SSH 公钥，跳过。"
  else
    yatta_ensure_authorized_keys "$YATTA_USER_NAME" "${YATTA_USER_SSH_KEYS[@]}" || return 1
  fi
fi

if [[ "${#YATTA_USER_DELETE_USERS[@]}" -gt 0 ]]; then
  for delete_user in "${YATTA_USER_DELETE_USERS[@]}"; do
    if yatta_user_is_protected "$delete_user"; then
      yatta_log_error "拒绝删除受保护用户：${delete_user}"
      return 1
    fi
    yatta_delete_user_keep_home "$delete_user" || return 1
  done
fi
}

yatta_module_user_post_apply() {
  return 0
}

yatta_module_packages_prompt() {
# packages 模块只处理 v1 文档规定的基础包，扩展包留给后续模块。
YATTA_BASE_PACKAGES=(curl wget git vim unzip ca-certificates gnupg lsb-release)
YATTA_PACKAGES_MISSING=()
YATTA_PACKAGES_INSTALL="0"
YATTA_PACKAGES_APT_UPDATE="0"
YATTA_PACKAGES_APT_UPGRADE="0"

while IFS= read -r package; do
  [[ -n "$package" ]] && YATTA_PACKAGES_MISSING+=("$package")
done < <(yatta_missing_packages "${YATTA_BASE_PACKAGES[@]}")

if [[ "${#YATTA_PACKAGES_MISSING[@]}" -eq 0 ]]; then
  yatta_plan_add "packages" "ok" "基础软件包已全部安装。"
elif yatta_ui_confirm "检测到缺失基础软件包：${YATTA_PACKAGES_MISSING[*]}。是否安装？" "y"; then
  YATTA_PACKAGES_INSTALL="1"
  YATTA_PACKAGES_APT_UPDATE="1"
  yatta_plan_add "packages" "info" "将安装基础软件包：${YATTA_PACKAGES_MISSING[*]}"
else
  yatta_plan_add "packages" "warn" "跳过基础软件包安装，缺失：${YATTA_PACKAGES_MISSING[*]}"
fi

if yatta_ui_confirm "是否在脚本全部执行完成后运行 apt upgrade？这可能升级大量系统包。" "n"; then
  YATTA_PACKAGES_APT_UPDATE="1"
  YATTA_PACKAGES_APT_UPGRADE="1"
  yatta_plan_add "packages" "warn" "将在所有模块完成后执行 apt upgrade 作为最后收尾任务。"
else
  yatta_plan_add "packages" "info" "跳过 apt upgrade 收尾任务。"
fi
}

yatta_module_packages_pre_apply() {
# packages 的前置阶段只负责刷新 apt 索引。这样后续需要安装软件包的模块
# 可以复用较新的包索引，同时把风险更高的 apt upgrade 留到最终收尾阶段。
if [[ "${YATTA_PACKAGES_APT_UPDATE:-0}" != "1" ]]; then
  yatta_log_info "没有需要提前刷新的 apt 索引。"
  return 0
fi

yatta_apt_update
}

yatta_module_packages_apply() {
# apply 阶段重新计算缺失包，避免重复运行时重新安装已满足的软件包。
if [[ "${YATTA_PACKAGES_INSTALL:-0}" != "1" ]]; then
  yatta_log_warn "已跳过基础软件包安装。"
  return 0
fi

fresh_missing=()
while IFS= read -r package; do
  [[ -n "$package" ]] && fresh_missing+=("$package")
done < <(yatta_missing_packages "${YATTA_BASE_PACKAGES[@]}")

if [[ "${#fresh_missing[@]}" -eq 0 ]]; then
  yatta_log_ok "基础软件包已全部安装。"
  return 0
fi

yatta_apt_install_missing "${fresh_missing[@]}"
}

yatta_module_packages_post_apply() {
# apt upgrade 可能触发较大范围的软件包升级，所以只在用户明确确认后，
# 作为全部模块完成后的最后收尾任务执行。
if [[ "${YATTA_PACKAGES_APT_UPGRADE:-0}" != "1" ]]; then
  yatta_log_info "已跳过 apt upgrade 收尾任务。"
  return 0
fi

yatta_log_warn "即将执行 apt upgrade，这是本次脚本的最后收尾任务。"
yatta_apt_upgrade
}

yatta_module_ufw_prompt() {
# UFW 是收尾模块，必须先确认并登记 SSH 放行策略，再允许启用防火墙。
YATTA_UFW_ENABLE="0"
YATTA_UFW_SSH_PORT="$(yatta_detect_ssh_port)"
YATTA_UFW_INSTALL_PACKAGE="0"
YATTA_UFW_SET_DENY_INCOMING="0"
YATTA_UFW_SET_ALLOW_OUTGOING="0"
YATTA_UFW_ALLOW_WEB="0"
YATTA_UFW_CONFIRMED_PORT_PLAN="0"

yatta_log_info "启用 UFW 时将自动执行：ufw default deny incoming；ufw default allow outgoing。启用前仍会先放行 SSH。"

if ! yatta_valid_port "$YATTA_UFW_SSH_PORT"; then
  yatta_log_warn "检测到的 SSH 端口无效，将默认使用 22，请确认。"
  YATTA_UFW_SSH_PORT="22"
fi

while true; do
  YATTA_UFW_SSH_PORT="$(yatta_ui_input "确认需要放行的 SSH 端口" "$YATTA_UFW_SSH_PORT")"
  if yatta_valid_port "$YATTA_UFW_SSH_PORT"; then
    break
  fi
  yatta_log_warn "端口必须是 1 到 65535 之间的数字。"
done

if yatta_ui_confirm "是否启用 UFW 防火墙？" "y"; then
  YATTA_UFW_ENABLE="1"
  YATTA_UFW_SET_DENY_INCOMING="1"
  YATTA_UFW_SET_ALLOW_OUTGOING="1"
  if yatta_package_installed "ufw"; then
    yatta_plan_add "ufw" "ok" "ufw 软件包已安装。"
  elif yatta_ui_confirm "未检测到 ufw 软件包，是否自动安装？" "y"; then
    YATTA_UFW_INSTALL_PACKAGE="1"
  else
    yatta_log_warn "未安装 ufw 且选择不自动安装，本次将跳过 UFW 配置。"
    YATTA_UFW_ENABLE="0"
  fi
fi

if [[ "$YATTA_UFW_ENABLE" == "1" ]]; then
  if yatta_ui_confirm "是否开放 HTTP/HTTPS 端口 80/443？" "n"; then
    YATTA_UFW_ALLOW_WEB="1"
    yatta_port_plan_add "ufw" "tcp" "80" "HTTP"
    yatta_port_plan_add "ufw" "tcp" "443" "HTTPS"
  fi
  yatta_port_plan_show
  if yatta_ui_confirm "请再次确认：是否按以上端口计划配置 UFW？" "y"; then
    YATTA_UFW_CONFIRMED_PORT_PLAN="1"
  else
    yatta_log_warn "未确认端口计划，本次将跳过 UFW 配置。"
    YATTA_UFW_ENABLE="0"
  fi
fi

if [[ "$YATTA_UFW_ENABLE" != "1" ]]; then
  yatta_plan_add "ufw" "warn" "跳过 UFW 配置。"
else
  yatta_plan_add "ufw" "info" "确认 SSH 放行端口：${YATTA_UFW_SSH_PORT}/tcp"
  if [[ "$YATTA_UFW_INSTALL_PACKAGE" == "1" ]]; then
    yatta_plan_add "ufw" "info" "将安装 ufw 软件包。"
  fi
  yatta_plan_add "ufw" "info" "执行固定默认策略：ufw default deny incoming"
  yatta_plan_add "ufw" "info" "执行固定默认策略：ufw default allow outgoing"
  yatta_plan_add "ufw" "info" "启用 UFW 前放行 SSH：${YATTA_UFW_SSH_PORT}/tcp"
  if [[ "${#YATTA_PORT_PLAN_PORTS[@]}" -gt 0 ]]; then
    yatta_plan_add "ufw" "info" "按已确认端口计划放行 ${#YATTA_PORT_PLAN_PORTS[@]} 条规则。"
  fi
  yatta_plan_add "ufw" "warn" "启用 UFW。请确认当前 SSH 连接端口已放行。"
fi
}

yatta_module_ufw_pre_apply() {
  return 0
}

yatta_module_ufw_apply() {
# 防火墙是远程连接敏感操作，apply 阶段再次校验 SSH 端口后才启用。
if [[ "${YATTA_UFW_ENABLE:-0}" != "1" ]]; then
  yatta_log_warn "已跳过 UFW 配置。"
  return 0
fi

if ! yatta_valid_port "${YATTA_UFW_SSH_PORT:-}"; then
  yatta_log_error "SSH 放行端口无效，已停止，避免锁定远程连接。"
  return 1
fi

if yatta_package_installed "ufw"; then
  yatta_log_ok "ufw 软件包已安装。"
elif [[ "${YATTA_UFW_INSTALL_PACKAGE:-0}" == "1" ]]; then
  yatta_ensure_package_installed "ufw" || return 1
else
  yatta_log_error "未安装 ufw，且未确认自动安装，已停止。"
  return 1
fi

if [[ "${YATTA_UFW_SET_DENY_INCOMING:-0}" == "1" ]]; then
  yatta_ufw_default_deny_incoming || return 1
fi

if [[ "${YATTA_UFW_SET_ALLOW_OUTGOING:-0}" == "1" ]]; then
  yatta_ufw_default_allow_outgoing || return 1
fi

yatta_ufw_allow_port "$YATTA_UFW_SSH_PORT" "tcp" || return 1

if [[ "${YATTA_UFW_CONFIRMED_PORT_PLAN:-0}" == "1" ]]; then
  for index in "${!YATTA_PORT_PLAN_PORTS[@]}"; do
    yatta_ufw_allow_port "${YATTA_PORT_PLAN_PORTS[$index]}" "${YATTA_PORT_PLAN_PROTOCOLS[$index]}" || return 1
  done
fi

yatta_ufw_enable
}

yatta_module_ufw_post_apply() {
  return 0
}

yatta_register_generated_modules() {
  yatta_module_register 'system-check' 'System Check' 'preflight' 'preflight' 'low' true true 'yatta_module_system_check_prompt' 'yatta_module_system_check_pre_apply' 'yatta_module_system_check_apply' 'yatta_module_system_check_post_apply'
  yatta_module_register 'hostname' 'Hostname' 'system' 'system-basics' 'low' true false 'yatta_module_hostname_prompt' 'yatta_module_hostname_pre_apply' 'yatta_module_hostname_apply' 'yatta_module_hostname_post_apply'
  yatta_module_register 'timezone' 'Timezone' 'system' 'system-basics' 'low' true false 'yatta_module_timezone_prompt' 'yatta_module_timezone_pre_apply' 'yatta_module_timezone_apply' 'yatta_module_timezone_post_apply'
  yatta_module_register 'swap' 'Swap' 'system' 'system-basics' 'medium' true false 'yatta_module_swap_prompt' 'yatta_module_swap_pre_apply' 'yatta_module_swap_apply' 'yatta_module_swap_post_apply'
  yatta_module_register 'user' 'User' 'account' 'account' 'medium' true false 'yatta_module_user_prompt' 'yatta_module_user_pre_apply' 'yatta_module_user_apply' 'yatta_module_user_post_apply'
  yatta_module_register 'packages' 'Packages' 'packages' 'packages' 'medium' true false 'yatta_module_packages_prompt' 'yatta_module_packages_pre_apply' 'yatta_module_packages_apply' 'yatta_module_packages_post_apply'
  yatta_module_register 'ufw' 'UFW' 'firewall' 'firewall' 'high' false false 'yatta_module_ufw_prompt' 'yatta_module_ufw_pre_apply' 'yatta_module_ufw_apply' 'yatta_module_ufw_post_apply'
}

yatta_main "$@"
