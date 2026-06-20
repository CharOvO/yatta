# 这里保存 runtime 的共享状态和小型工具函数。它必须最先被拼接，
# 让后续 UI、系统探测、适配器和主流程都能使用同一套计划与模块注册结构。

YATTA_MODULE_IDS=()
YATTA_MODULE_NAMES=()
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
  YATTA_MODULE_PROMPT_FNS+=("$3")
  YATTA_MODULE_PRE_APPLY_FNS+=("$4")
  YATTA_MODULE_APPLY_FNS+=("$5")
  YATTA_MODULE_POST_APPLY_FNS+=("$6")
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
  [[ -r /dev/tty && -w /dev/tty ]]
}

yatta_test_mode() {
  [[ "${YATTA_TEST_MODE:-}" == "1" ]]
}

yatta_dry_run() {
  [[ "${YATTA_DRY_RUN:-}" == "1" ]]
}
