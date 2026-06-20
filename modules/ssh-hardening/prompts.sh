# SSH 加固是远程访问高风险模块。prompt 阶段只读取当前配置、确认风险并登记计划，
# 真正的 sshd drop-in 写入、校验和 reload 必须等用户确认完整执行计划后再进行。
YATTA_SSH_ACTION="configure"
YATTA_SSH_TARGET_USER=""
YATTA_SSH_HAS_KEY_EVIDENCE="0"
YATTA_SSH_TARGET_PORT=""
YATTA_SSH_SET_PORT="0"
YATTA_SSH_OLD_PORT=""
YATTA_SSH_SET_PERMIT_ROOT_LOGIN="0"
YATTA_SSH_PERMIT_ROOT_LOGIN=""
YATTA_SSH_SET_PASSWORD_AUTHENTICATION="0"
YATTA_SSH_PASSWORD_AUTHENTICATION=""
YATTA_SSH_SET_KBD_INTERACTIVE_AUTHENTICATION="0"
YATTA_SSH_KBD_INTERACTIVE_AUTHENTICATION=""
YATTA_SSH_SET_PUBKEY_AUTHENTICATION="0"
YATTA_SSH_PUBKEY_AUTHENTICATION=""
YATTA_SSH_SET_PERMIT_EMPTY_PASSWORDS="0"
YATTA_SSH_PERMIT_EMPTY_PASSWORDS=""
YATTA_SSH_SET_MAX_AUTH_TRIES="0"
YATTA_SSH_MAX_AUTH_TRIES=""
YATTA_SSH_SET_LOGIN_GRACE_TIME="0"
YATTA_SSH_LOGIN_GRACE_TIME=""
YATTA_SSH_SET_X11_FORWARDING="0"
YATTA_SSH_X11_FORWARDING=""

YATTA_SSH_OLD_PORT="$(yatta_detect_ssh_port)"
if ! yatta_valid_port "$YATTA_SSH_OLD_PORT"; then
  YATTA_SSH_OLD_PORT="22"
fi
YATTA_SSH_TARGET_PORT="$YATTA_SSH_OLD_PORT"
current_root_login="$(yatta_sshd_effective_value "permitrootlogin" "prohibit-password")"
current_password_auth="$(yatta_sshd_effective_value "passwordauthentication" "yes")"
current_kbd_auth="$(yatta_sshd_effective_value "kbdinteractiveauthentication" "yes")"
current_pubkey_auth="$(yatta_sshd_effective_value "pubkeyauthentication" "yes")"
current_empty_passwords="$(yatta_sshd_effective_value "permitemptypasswords" "no")"
current_max_auth_tries="$(yatta_sshd_effective_value "maxauthtries" "6")"
current_login_grace_time="$(yatta_sshd_effective_value "logingracetime" "120")"
current_x11_forwarding="$(yatta_sshd_effective_value "x11forwarding" "yes")"

yatta_log_warn "SSH 加固可能影响远程登录。建议保持当前 SSH 会话，同时另开终端验证新登录路径。"
yatta_log_info "当前 SSH 摘要：端口 ${YATTA_SSH_OLD_PORT}，root=${current_root_login}，password=${current_password_auth}，kbd-interactive=${current_kbd_auth}，pubkey=${current_pubkey_auth}。"

if [[ "${YATTA_USER_ACTION:-skip}" != "skip" && -n "${YATTA_USER_NAME:-}" ]] && yatta_valid_username "${YATTA_USER_NAME:-}"; then
  YATTA_SSH_TARGET_USER="$YATTA_USER_NAME"
  if [[ "${YATTA_USER_IMPORT_KEYS:-0}" == "1" && "${#YATTA_USER_SSH_KEYS[@]}" -gt 0 ]]; then
    YATTA_SSH_HAS_KEY_EVIDENCE="1"
  elif yatta_user_has_authorized_keys "$YATTA_SSH_TARGET_USER"; then
    YATTA_SSH_HAS_KEY_EVIDENCE="1"
  fi
  yatta_log_info "将使用 user 模块的目标 sudo 用户作为 SSH 安全闸门用户：${YATTA_SSH_TARGET_USER}"
else
  sudo_candidates=()
  while IFS= read -r candidate_user; do
    candidate_user="$(yatta_string_trim "$candidate_user")"
    [[ -z "$candidate_user" ]] && continue
    if yatta_user_in_group "$candidate_user" "sudo"; then
      sudo_candidates+=("$candidate_user")
    fi
  done < <(yatta_list_normal_users)
  if [[ "${#sudo_candidates[@]}" -gt 0 ]]; then
    sudo_candidates+=("不选择目标用户")
    selected_user="$(yatta_ui_select "选择用于验证 SSH 密钥登录的 sudo 用户" 0 "${sudo_candidates[@]}")"
    if [[ "$selected_user" != "不选择目标用户" ]]; then
      YATTA_SSH_TARGET_USER="$selected_user"
      if yatta_user_has_authorized_keys "$YATTA_SSH_TARGET_USER"; then
        YATTA_SSH_HAS_KEY_EVIDENCE="1"
      fi
    fi
  else
    yatta_log_warn "未找到可用于验证密钥登录的普通 sudo 用户。"
  fi
fi

if [[ -n "$YATTA_SSH_TARGET_USER" && "$YATTA_SSH_HAS_KEY_EVIDENCE" == "1" ]]; then
  yatta_log_ok "检测到 ${YATTA_SSH_TARGET_USER} 的密钥登录证据。"
elif [[ -n "$YATTA_SSH_TARGET_USER" ]]; then
  yatta_log_warn "未检测到 ${YATTA_SSH_TARGET_USER} 的密钥登录证据；本次不会禁用密码登录或完全禁用 root。"
else
  yatta_log_warn "未选择目标 sudo 用户；本次不会禁用密码登录或完全禁用 root。"
fi

port_choice="$(yatta_ui_select "SSH 端口策略" 0 "保持当前端口：${YATTA_SSH_OLD_PORT}" "手动输入新端口")"
case "$port_choice" in
  手动输入新端口)
    while true; do
      YATTA_SSH_TARGET_PORT="$(yatta_ui_input "新的 SSH 端口（1-65535）" "")"
      if yatta_valid_port "$YATTA_SSH_TARGET_PORT"; then
        break
      fi
      yatta_log_warn "端口必须是 1 到 65535 之间的数字。"
    done
    if [[ "$YATTA_SSH_TARGET_PORT" != "$YATTA_SSH_OLD_PORT" ]]; then
      YATTA_SSH_SET_PORT="1"
      yatta_port_plan_add "ssh-hardening" "tcp" "$YATTA_SSH_TARGET_PORT" "SSH 新端口"
      yatta_port_plan_add "ssh-hardening" "tcp" "$YATTA_SSH_OLD_PORT" "SSH 临时保底放行旧端口"
      yatta_log_warn "旧端口只会登记给 UFW 临时放行；sshd 本身将只监听新端口。"
    fi
    ;;
esac

root_choice="$(yatta_ui_select "root 登录策略" 0 "完全禁用 root 登录（推荐）" "仅禁止 root 密码登录" "保持当前：${current_root_login}")"
case "$root_choice" in
  完全禁用*)
    if [[ -n "$YATTA_SSH_TARGET_USER" && "$YATTA_SSH_HAS_KEY_EVIDENCE" == "1" ]]; then
      YATTA_SSH_SET_PERMIT_ROOT_LOGIN="1"
      YATTA_SSH_PERMIT_ROOT_LOGIN="no"
    else
      yatta_log_warn "缺少可用 sudo 用户或密钥证据，已保持 root 登录策略不变。"
    fi
    ;;
  仅禁止*)
    YATTA_SSH_SET_PERMIT_ROOT_LOGIN="1"
    YATTA_SSH_PERMIT_ROOT_LOGIN="prohibit-password"
    ;;
esac

password_choice="$(yatta_ui_select "密码与键盘交互登录策略" 0 "禁用密码和键盘交互登录（推荐）" "保持当前：password=${current_password_auth}, kbd=${current_kbd_auth}" "启用密码和键盘交互登录")"
case "$password_choice" in
  禁用*)
    if [[ "$YATTA_SSH_HAS_KEY_EVIDENCE" == "1" ]]; then
      YATTA_SSH_SET_PASSWORD_AUTHENTICATION="1"
      YATTA_SSH_PASSWORD_AUTHENTICATION="no"
      YATTA_SSH_SET_KBD_INTERACTIVE_AUTHENTICATION="1"
      YATTA_SSH_KBD_INTERACTIVE_AUTHENTICATION="no"
    else
      yatta_log_warn "缺少密钥登录证据，已保持密码与键盘交互登录策略不变。"
    fi
    ;;
  启用*)
    YATTA_SSH_SET_PASSWORD_AUTHENTICATION="1"
    YATTA_SSH_PASSWORD_AUTHENTICATION="yes"
    YATTA_SSH_SET_KBD_INTERACTIVE_AUTHENTICATION="1"
    YATTA_SSH_KBD_INTERACTIVE_AUTHENTICATION="yes"
    ;;
esac

pubkey_choice="$(yatta_ui_select "密钥登录策略" 0 "启用密钥登录（推荐）" "保持当前：${current_pubkey_auth}")"
case "$pubkey_choice" in
  启用*)
    YATTA_SSH_SET_PUBKEY_AUTHENTICATION="1"
    YATTA_SSH_PUBKEY_AUTHENTICATION="yes"
    ;;
esac

empty_choice="$(yatta_ui_select "空密码策略" 0 "禁用空密码登录（推荐）" "保持当前：${current_empty_passwords}")"
case "$empty_choice" in
  禁用*)
    YATTA_SSH_SET_PERMIT_EMPTY_PASSWORDS="1"
    YATTA_SSH_PERMIT_EMPTY_PASSWORDS="no"
    ;;
esac

max_auth_choice="$(yatta_ui_select "认证重试次数" 0 "设置 MaxAuthTries 为 3（推荐）" "保持当前：${current_max_auth_tries}" "手动输入 MaxAuthTries")"
case "$max_auth_choice" in
  设置*)
    YATTA_SSH_SET_MAX_AUTH_TRIES="1"
    YATTA_SSH_MAX_AUTH_TRIES="3"
    ;;
  手动输入*)
    while true; do
      YATTA_SSH_MAX_AUTH_TRIES="$(yatta_ui_input "MaxAuthTries（1-10）" "3")"
      if [[ "$YATTA_SSH_MAX_AUTH_TRIES" =~ ^[0-9]+$ ]] && ((YATTA_SSH_MAX_AUTH_TRIES >= 1 && YATTA_SSH_MAX_AUTH_TRIES <= 10)); then
        YATTA_SSH_SET_MAX_AUTH_TRIES="1"
        break
      fi
      yatta_log_warn "MaxAuthTries 必须是 1 到 10 之间的整数。"
    done
    ;;
esac

grace_choice="$(yatta_ui_select "登录宽限时间" 0 "设置 LoginGraceTime 为 30s（推荐）" "保持当前：${current_login_grace_time}" "手动输入秒数")"
case "$grace_choice" in
  设置*)
    YATTA_SSH_SET_LOGIN_GRACE_TIME="1"
    YATTA_SSH_LOGIN_GRACE_TIME="30"
    ;;
  手动输入*)
    while true; do
      YATTA_SSH_LOGIN_GRACE_TIME="$(yatta_ui_input "LoginGraceTime 秒数（10-300）" "30")"
      if [[ "$YATTA_SSH_LOGIN_GRACE_TIME" =~ ^[0-9]+$ ]] && ((YATTA_SSH_LOGIN_GRACE_TIME >= 10 && YATTA_SSH_LOGIN_GRACE_TIME <= 300)); then
        YATTA_SSH_SET_LOGIN_GRACE_TIME="1"
        break
      fi
      yatta_log_warn "LoginGraceTime 必须是 10 到 300 之间的整数秒。"
    done
    ;;
esac

x11_choice="$(yatta_ui_select "X11 转发策略" 0 "禁用 X11Forwarding（推荐）" "保持当前：${current_x11_forwarding}")"
case "$x11_choice" in
  禁用*)
    YATTA_SSH_SET_X11_FORWARDING="1"
    YATTA_SSH_X11_FORWARDING="no"
    ;;
esac

if [[ "$YATTA_SSH_SET_PORT" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "warn" "将 SSH 监听端口改为 ${YATTA_SSH_TARGET_PORT}；旧端口 ${YATTA_SSH_OLD_PORT} 仅登记为 UFW 临时保底放行。"
else
  yatta_plan_add "ssh-hardening" "info" "保持 SSH 端口不变：${YATTA_SSH_OLD_PORT}。"
fi

if [[ "$YATTA_SSH_SET_PERMIT_ROOT_LOGIN" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "warn" "将设置 PermitRootLogin ${YATTA_SSH_PERMIT_ROOT_LOGIN}。"
fi
if [[ "$YATTA_SSH_SET_PASSWORD_AUTHENTICATION" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "warn" "将设置 PasswordAuthentication ${YATTA_SSH_PASSWORD_AUTHENTICATION}。"
fi
if [[ "$YATTA_SSH_SET_KBD_INTERACTIVE_AUTHENTICATION" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "warn" "将设置 KbdInteractiveAuthentication ${YATTA_SSH_KBD_INTERACTIVE_AUTHENTICATION}。"
fi
if [[ "$YATTA_SSH_SET_PUBKEY_AUTHENTICATION" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "info" "将设置 PubkeyAuthentication ${YATTA_SSH_PUBKEY_AUTHENTICATION}。"
fi
if [[ "$YATTA_SSH_SET_PERMIT_EMPTY_PASSWORDS" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "info" "将设置 PermitEmptyPasswords ${YATTA_SSH_PERMIT_EMPTY_PASSWORDS}。"
fi
if [[ "$YATTA_SSH_SET_MAX_AUTH_TRIES" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "info" "将设置 MaxAuthTries ${YATTA_SSH_MAX_AUTH_TRIES}。"
fi
if [[ "$YATTA_SSH_SET_LOGIN_GRACE_TIME" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "info" "将设置 LoginGraceTime ${YATTA_SSH_LOGIN_GRACE_TIME}s。"
fi
if [[ "$YATTA_SSH_SET_X11_FORWARDING" == "1" ]]; then
  yatta_plan_add "ssh-hardening" "info" "将设置 X11Forwarding ${YATTA_SSH_X11_FORWARDING}。"
fi
yatta_plan_add "ssh-hardening" "warn" "写入 SSH drop-in 后会先执行 sshd -t 和有效值校验，成功后仅 reload SSH 服务。"
