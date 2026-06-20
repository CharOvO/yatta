# 这里封装 Ubuntu 上的系统修改命令。模块只调用这些函数，
# 这样后续更换发行版适配或补充 dry-run 验证时不用修改每个模块。

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
