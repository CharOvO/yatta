# apply 阶段才调用 adduser，让系统工具处理密码，脚本不保存明文密码。
if [[ "${YATTA_USER_ACTION:-skip}" == "skip" ]]; then
  yatta_log_warn "已跳过非 root sudo 用户创建。"
  return 0
fi

if [[ -z "${YATTA_USER_NAME:-}" || "$YATTA_USER_NAME" == "root" ]]; then
  yatta_log_error "sudo 用户名无效，已停止。"
  return 1
fi

if yatta_user_exists "$YATTA_USER_NAME"; then
  yatta_log_info "用户 ${YATTA_USER_NAME} 已存在。"
  yatta_ensure_sudo_group "$YATTA_USER_NAME"
else
  yatta_add_sudo_user "$YATTA_USER_NAME"
fi
