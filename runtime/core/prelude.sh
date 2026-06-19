# 这里保存 runtime 的共享状态和小型工具函数。它必须最先被拼接，
# 让后续 UI、系统探测、适配器和主流程都能使用同一套计划与模块注册结构。

YATTA_MODULE_IDS=()
YATTA_MODULE_NAMES=()
YATTA_MODULE_PROMPT_FNS=()
YATTA_MODULE_APPLY_FNS=()

YATTA_PLAN_MODULES=()
YATTA_PLAN_LEVELS=()
YATTA_PLAN_MESSAGES=()

yatta_module_register() {
  YATTA_MODULE_IDS+=("$1")
  YATTA_MODULE_NAMES+=("$2")
  YATTA_MODULE_PROMPT_FNS+=("$3")
  YATTA_MODULE_APPLY_FNS+=("$4")
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

yatta_call_function() {
  local fn="$1"
  if ! declare -F "$fn" >/dev/null 2>&1; then
    yatta_log_error "缺少函数：${fn}"
    return 1
  fi
  "$fn"
}

yatta_has_tty() {
  [[ -t 0 && -t 1 ]]
}

yatta_test_mode() {
  [[ "${YATTA_TEST_MODE:-}" == "1" ]]
}

yatta_dry_run() {
  [[ "${YATTA_DRY_RUN:-}" == "1" ]]
}
