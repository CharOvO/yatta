# 这里封装跨模块复用或平台差异明显的 Ubuntu 系统修改命令。
# 模块私有的一次性流程可以留在模块内，但仍应复用 yatta_run_command
# 获得一致的 dry-run 行为。

yatta_command_preview() {
  local part
  for part in "$@"; do
    printf '%q ' "$part"
  done
}

yatta_run_command() {
  if yatta_dry_run; then
    yatta_log_info "[dry-run] $(yatta_command_preview "$@")"
    return 0
  fi
  "$@"
}

yatta_apt_update() {
  yatta_run_command apt-get update
}

yatta_apt_install() {
  yatta_run_command apt-get install -y "$@"
}

yatta_apt_upgrade() {
  yatta_run_command apt-get upgrade -y
}

yatta_apt_install_missing() {
  local packages=("$@")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    yatta_log_ok "没有缺失的软件包需要安装。"
    return 0
  fi
  yatta_apt_install "${packages[@]}"
}

yatta_ensure_package_installed() {
  local package="$1"
  if yatta_package_installed "$package"; then
    yatta_log_ok "软件包已安装：${package}"
    return 0
  fi
  yatta_apt_update || return 1
  yatta_apt_install "$package"
}

yatta_ufw_default_deny_incoming() {
  yatta_run_command ufw default deny incoming
}

yatta_ufw_default_allow_outgoing() {
  yatta_run_command ufw default allow outgoing
}

yatta_ufw_allow_port() {
  local port="$1"
  local proto="${2:-tcp}"
  yatta_run_command ufw allow "${port}/${proto}"
}

yatta_ufw_enable() {
  yatta_run_command ufw --force enable
}

yatta_set_timezone() {
  local timezone="$1"
  yatta_run_command timedatectl set-timezone "$timezone"
}

yatta_set_hostname() {
  local hostname="$1"
  yatta_run_command hostnamectl set-hostname "$hostname"
}

yatta_add_sudo_user() {
  local username="$1"
  yatta_run_command adduser "$username" || return 1
  yatta_ensure_sudo_group "$username"
}

yatta_ensure_sudo_group() {
  local username="$1"
  if yatta_user_in_group "$username" "sudo"; then
    yatta_log_ok "用户 ${username} 已在 sudo 组中。"
    return 0
  fi
  yatta_run_command usermod -aG sudo "$username"
}

yatta_ensure_sudo_nopasswd() {
  local username="$1"
  local target="/etc/sudoers.d/yatta-${username}"
  local content="${username} ALL=(ALL) NOPASSWD:ALL"$'\n'
  local tmp
  if [[ -f "$target" ]] && [[ "$(cat "$target")" == "$content" ]]; then
    yatta_log_ok "sudo 免密配置已是期望内容：${target}"
    return 0
  fi
  if yatta_dry_run; then
    yatta_log_info "[dry-run] write validated sudoers drop-in ${target}"
    return 0
  fi
  if ! yatta_command_exists visudo; then
    yatta_log_error "缺少 visudo，无法安全写入 sudoers 配置。"
    return 1
  fi
  tmp="$(mktemp)" || return 1
  printf '%s' "$content" >"$tmp"
  chmod 0440 "$tmp"
  if ! visudo -cf "$tmp" >/dev/null; then
    rm -f "$tmp"
    yatta_log_error "sudoers drop-in 校验失败，未写入免密配置。"
    return 1
  fi
  install -m 0440 "$tmp" "$target"
  rm -f "$tmp"
}

yatta_ensure_authorized_keys() {
  local username="$1"
  shift
  local home ssh_dir auth_file key
  home="$(yatta_user_home "$username")"
  if [[ -z "$home" ]]; then
    yatta_log_error "无法确定用户 ${username} 的 home 目录。"
    return 1
  fi
  ssh_dir="${home}/.ssh"
  auth_file="${ssh_dir}/authorized_keys"
  if yatta_dry_run; then
    yatta_log_info "[dry-run] ensure ${auth_file} with $# SSH public key(s)"
    return 0
  fi
  install -d -m 0700 -o "$username" -g "$username" "$ssh_dir" || return 1
  touch "$auth_file" || return 1
  chown "$username:$username" "$auth_file" || return 1
  chmod 0600 "$auth_file" || return 1
  for key in "$@"; do
    if grep -Fx -- "$key" "$auth_file" >/dev/null 2>&1; then
      continue
    fi
    printf '%s\n' "$key" >>"$auth_file"
  done
}

yatta_delete_user_keep_home() {
  local username="$1"
  if yatta_user_is_protected "$username"; then
    yatta_log_error "拒绝删除受保护用户：${username}"
    return 1
  fi
  if ! yatta_user_exists "$username"; then
    yatta_log_ok "用户 ${username} 不存在，跳过删除。"
    return 0
  fi
  if yatta_command_exists deluser; then
    yatta_run_command deluser "$username"
  else
    yatta_run_command userdel "$username"
  fi
}

yatta_backup_file() {
  local path="$1"
  local backup
  [[ -f "$path" ]] || return 0
  backup="${path}.yatta.bak.$(date +%Y%m%d%H%M%S)"
  yatta_run_command cp -a "$path" "$backup"
}

yatta_write_file_if_changed() {
  local path="$1"
  local content="$2"
  if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$content" ]]; then
    yatta_log_ok "文件已是期望内容：${path}"
    return 0
  fi
  if yatta_dry_run; then
    yatta_log_info "[dry-run] write ${path}"
    return 0
  fi
  printf '%s' "$content" >"$path"
}
