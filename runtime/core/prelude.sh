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

YATTA_FINAL_TASK_NAMES=()
YATTA_FINAL_TASK_FNS=()

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
  local index marker locked_label
  printf '%s\n' "本次启用模块：" >&2
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    marker="[ ]"
    yatta_module_is_enabled "$index" && marker="[x]"
    locked_label=""
    [[ "${YATTA_MODULE_LOCKED[$index]}" == "true" ]] && locked_label=" locked"
    printf '  %s %d. %s | stage=%s | group=%s | risk=%s%s\n' \
      "$marker" \
      "$((index + 1))" \
      "${YATTA_MODULE_NAMES[$index]}" \
      "${YATTA_MODULE_STAGES[$index]}" \
      "${YATTA_MODULE_GROUPS[$index]}" \
      "${YATTA_MODULE_RISKS[$index]}" \
      "$locked_label" >&2
  done
}

yatta_module_selection_prompt() {
  local index selected_csv locked_csv locked_label chosen_index
  local options=()
  local chosen=()
  selected_csv=""
  locked_csv=""
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    locked_label=""
    [[ "${YATTA_MODULE_LOCKED[$index]}" == "true" ]] && locked_label=" locked"
    options+=("$((index + 1)). ${YATTA_MODULE_NAMES[$index]} | stage=${YATTA_MODULE_STAGES[$index]} | group=${YATTA_MODULE_GROUPS[$index]} | risk=${YATTA_MODULE_RISKS[$index]}${locked_label}")
    if yatta_module_is_enabled "$index"; then
      selected_csv="${selected_csv:+$selected_csv,}$index"
    fi
    if [[ "${YATTA_MODULE_LOCKED[$index]}" == "true" ]]; then
      locked_csv="${locked_csv:+$locked_csv,}$index"
    fi
  done
  while IFS= read -r chosen_index; do
    [[ "$chosen_index" =~ ^[0-9]+$ ]] && chosen[$chosen_index]="true"
  done < <(yatta_ui_multi_select "选择本次启用模块" "$selected_csv" "$locked_csv" "${options[@]}")

  for index in "${!YATTA_MODULE_IDS[@]}"; do
    if [[ "${YATTA_MODULE_LOCKED[$index]}" == "true" ]]; then
      YATTA_MODULE_ENABLED[$index]="true"
    elif [[ "${chosen[$index]:-false}" == "true" ]]; then
      YATTA_MODULE_ENABLED[$index]="true"
    else
      YATTA_MODULE_ENABLED[$index]="false"
    fi
  done
  yatta_module_selection_show
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

yatta_final_task_add() {
  local name="$1"
  local fn="$2"
  YATTA_FINAL_TASK_NAMES+=("$name")
  YATTA_FINAL_TASK_FNS+=("$fn")
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
