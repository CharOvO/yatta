# user 模块不收集密码；新用户密码交给 apply 阶段的 adduser 交互处理。
YATTA_USER_ACTION="skip"
YATTA_USER_NAME=""

if yatta_ui_confirm "是否创建或确认一个非 root sudo 用户？" "y"; then
  default_user="${SUDO_USER:-deploy}"
  [[ "$default_user" == "root" ]] && default_user="deploy"
  while true; do
    YATTA_USER_NAME="$(yatta_ui_input "sudo 用户名" "$default_user")"
    if [[ "$YATTA_USER_NAME" == "root" ]]; then
      yatta_log_warn "root 已存在且不作为本模块创建目标，请输入非 root 用户名。"
      continue
    fi
    if [[ "$YATTA_USER_NAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
      YATTA_USER_ACTION="ensure"
      break
    fi
    yatta_log_warn "用户名需以小写字母或下划线开头，只包含小写字母、数字、下划线或短横线，最长 32 个字符。"
  done
fi

if [[ "$YATTA_USER_ACTION" == "skip" ]]; then
  yatta_plan_add "user" "warn" "跳过非 root sudo 用户创建。"
elif yatta_user_exists "$YATTA_USER_NAME"; then
  if yatta_user_in_group "$YATTA_USER_NAME" "sudo"; then
    yatta_plan_add "user" "ok" "用户 ${YATTA_USER_NAME} 已存在且已在 sudo 组。"
  else
    yatta_plan_add "user" "info" "用户 ${YATTA_USER_NAME} 已存在，将加入 sudo 组。"
  fi
else
  yatta_plan_add "user" "info" "将创建非 root sudo 用户 ${YATTA_USER_NAME}；密码由 adduser 在执行阶段处理。"
fi
