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
