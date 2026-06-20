# UFW 是收尾模块，必须先确认并登记 SSH 放行策略，再允许启用防火墙。
YATTA_UFW_ENABLE="0"
if [[ "${YATTA_SSH_SET_PORT:-0}" == "1" && -n "${YATTA_SSH_TARGET_PORT:-}" ]]; then
  YATTA_UFW_SSH_PORT="$YATTA_SSH_TARGET_PORT"
else
  YATTA_UFW_SSH_PORT="$(yatta_detect_ssh_port)"
fi
YATTA_UFW_INSTALL_PACKAGE="0"
YATTA_UFW_SET_DENY_INCOMING="0"
YATTA_UFW_SET_ALLOW_OUTGOING="0"
YATTA_UFW_ALLOW_WEB="0"
YATTA_UFW_CONFIRMED_PORT_PLAN="0"

yatta_log_info "启用 UFW 时将自动执行：ufw default deny incoming；ufw default allow outgoing。启用前仍会先放行 SSH。"
if [[ "${YATTA_SSH_SET_PORT:-0}" == "1" && "$YATTA_UFW_SSH_PORT" == "${YATTA_SSH_TARGET_PORT:-}" ]]; then
  yatta_log_info "已读取 SSH 加固模块的新端口作为默认 SSH 放行端口：${YATTA_UFW_SSH_PORT}"
fi

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
    port_plan_extra_count="0"
    for index in "${!YATTA_PORT_PLAN_PORTS[@]}"; do
      if [[ "${YATTA_PORT_PLAN_PORTS[$index]}" == "$YATTA_UFW_SSH_PORT" && "${YATTA_PORT_PLAN_PROTOCOLS[$index]}" == "tcp" ]]; then
        continue
      fi
      port_plan_extra_count=$((port_plan_extra_count + 1))
    done
    if [[ "$port_plan_extra_count" -gt 0 ]]; then
      yatta_plan_add "ufw" "info" "按已确认端口计划额外放行 ${port_plan_extra_count} 条规则。"
    fi
  fi
  yatta_plan_add "ufw" "warn" "启用 UFW。请确认当前 SSH 连接端口已放行。"
fi
