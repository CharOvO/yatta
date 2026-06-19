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
