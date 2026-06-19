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
