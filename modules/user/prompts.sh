# user 模块只收集账户初始化意图。密码交给 adduser，SSH 服务安全策略交给后续 ssh-hardening。
YATTA_USER_ACTION="skip"
YATTA_USER_NAME=""
YATTA_USER_SUDO_NOPASSWD="0"
YATTA_USER_IMPORT_KEYS="0"
YATTA_USER_SSH_KEYS=()
YATTA_USER_DELETE_USERS=()

if yatta_ui_confirm "是否创建或确认一个非 root sudo 用户？" "y"; then
  default_user="${SUDO_USER:-deploy}"
  [[ "$default_user" == "root" ]] && default_user="deploy"
  while true; do
    YATTA_USER_NAME="$(yatta_ui_input "sudo 用户名" "$default_user")"
    if yatta_valid_username "$YATTA_USER_NAME"; then
      YATTA_USER_ACTION="ensure"
      break
    fi
    yatta_log_warn "用户名需以小写字母或下划线开头，只包含小写字母、数字、下划线或短横线，最长 32 个字符，且不能是 root。"
  done

  if yatta_ui_confirm "是否为 ${YATTA_USER_NAME} 设置 sudo 免密？" "n"; then
    YATTA_USER_SUDO_NOPASSWD="1"
  fi

  if yatta_ui_confirm "是否向 ${YATTA_USER_NAME} 导入 SSH 公钥？" "n"; then
    while IFS= read -r key_line; do
      key_line="$(yatta_string_trim "$key_line")"
      [[ -z "$key_line" ]] && continue
      if ! yatta_valid_ssh_public_key "$key_line"; then
        yatta_log_warn "忽略格式不像 OpenSSH 公钥的输入。"
        continue
      fi
      duplicate="0"
      for existing_key in "${YATTA_USER_SSH_KEYS[@]}"; do
        [[ "$existing_key" == "$key_line" ]] && duplicate="1"
      done
      [[ "$duplicate" == "1" ]] && continue
      YATTA_USER_SSH_KEYS+=("$key_line")
    done < <(yatta_ui_multiline_input "请粘贴 SSH 公钥，每行一个。")
    if [[ "${#YATTA_USER_SSH_KEYS[@]}" -gt 0 ]]; then
      YATTA_USER_IMPORT_KEYS="1"
    else
      yatta_log_warn "没有收到可导入的有效 SSH 公钥。"
    fi
  fi

  candidate_users=()
  while IFS= read -r candidate_user; do
    candidate_user="$(yatta_string_trim "$candidate_user")"
    [[ -z "$candidate_user" ]] && continue
    yatta_user_is_protected "$candidate_user" && continue
    candidate_users+=("$candidate_user")
  done < <(yatta_list_normal_users)

  if [[ "${#candidate_users[@]}" -gt 0 ]]; then
    yatta_log_info "可检查的普通用户：${candidate_users[*]}"
    if yatta_ui_confirm "是否逐个确认删除多余普通用户？默认保留 home。" "n"; then
      for candidate_user in "${candidate_users[@]}"; do
        if yatta_ui_confirm "确认删除用户 ${candidate_user}？" "n"; then
          YATTA_USER_DELETE_USERS+=("$candidate_user")
        fi
      done
    fi
  fi
fi

if [[ "$YATTA_USER_ACTION" == "skip" ]]; then
  yatta_plan_add "user" "warn" "跳过非 root sudo 用户创建。"
else
  if yatta_user_exists "$YATTA_USER_NAME"; then
    if yatta_user_in_group "$YATTA_USER_NAME" "sudo"; then
      yatta_plan_add "user" "ok" "用户 ${YATTA_USER_NAME} 已存在且已在 sudo 组。"
    else
      yatta_plan_add "user" "info" "用户 ${YATTA_USER_NAME} 已存在，将加入 sudo 组。"
    fi
  else
    yatta_plan_add "user" "info" "将创建非 root sudo 用户 ${YATTA_USER_NAME}；密码由 adduser 在执行阶段处理。"
  fi

  if [[ "$YATTA_USER_SUDO_NOPASSWD" == "1" ]]; then
    yatta_plan_add "user" "warn" "将为 ${YATTA_USER_NAME} 写入独立 sudo 免密配置。"
  else
    yatta_plan_add "user" "info" "不设置 sudo 免密。"
  fi

  if [[ "$YATTA_USER_IMPORT_KEYS" == "1" ]]; then
    yatta_plan_add "user" "info" "将向 ${YATTA_USER_NAME} 导入 ${#YATTA_USER_SSH_KEYS[@]} 个 SSH 公钥。"
  else
    yatta_plan_add "user" "info" "不导入 SSH 公钥。"
  fi

  if [[ "${#YATTA_USER_DELETE_USERS[@]}" -gt 0 ]]; then
    yatta_plan_add "user" "warn" "将删除普通用户（保留 home）：${YATTA_USER_DELETE_USERS[*]}"
  else
    yatta_plan_add "user" "info" "不删除其他普通用户。"
  fi
fi
