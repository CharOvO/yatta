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
