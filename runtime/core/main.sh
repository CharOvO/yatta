# 这里是生成脚本的主流程入口。它只负责把启动检查、模块 prompt、
# 执行计划确认和 apply 顺序串起来；具体 UI、系统探测和 Ubuntu 命令封装
# 分别放在 runtime/ui、runtime/system 和 runtime/adapter 中。

yatta_run_prompts() {
  local index id name prompt_fn
  for index in "${!YATTA_MODULE_IDS[@]}"; do
    id="${YATTA_MODULE_IDS[$index]}"
    name="${YATTA_MODULE_NAMES[$index]}"
    prompt_fn="${YATTA_MODULE_PROMPT_FNS[$index]}"
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
