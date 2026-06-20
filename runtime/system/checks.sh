# 这里集中处理脚本入口硬检查和环境摘要。runtime 负责阻断 v1 明确
# 不支持的环境；system-check 模块只调用这些探测函数来展示更完整的状态。

yatta_command_exists() {
  if yatta_test_mode; then
    return 0
  fi
  command -v "$1" >/dev/null 2>&1
}

yatta_is_root() {
  if yatta_test_mode; then
    [[ "${YATTA_TEST_ROOT_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

yatta_is_ubuntu() {
  if yatta_test_mode; then
    [[ "${YATTA_TEST_UBUNTU_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]]
}

yatta_ubuntu_version() {
  if yatta_test_mode; then
    printf '%s\n' "Ubuntu test-mode"
    return 0
  fi
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf '%s\n' "${PRETTY_NAME:-Ubuntu}"
    return 0
  fi
  printf '%s\n' "未知"
}

yatta_bash_version() {
  printf '%s\n' "${BASH_VERSION:-unknown}"
}

yatta_systemd_available() {
  if yatta_test_mode; then
    return 0
  fi
  yatta_command_exists systemctl && [[ -d /run/systemd/system ]]
}

yatta_apt_available() {
  yatta_command_exists apt-get && yatta_command_exists apt
}

yatta_network_status() {
  if yatta_test_mode; then
    [[ "${YATTA_TEST_NETWORK_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  if yatta_command_exists getent && getent hosts archive.ubuntu.com >/dev/null 2>&1; then
    return 0
  fi
  if yatta_command_exists ping && ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

yatta_current_hostname() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_HOSTNAME:-yatta-test-host}"
    return 0
  fi
  hostname
}

yatta_valid_hostname() {
  local hostname="$1"
  local label
  local labels
  [[ -n "$hostname" && "${#hostname}" -le 253 ]] || return 1
  [[ "$hostname" != .* && "$hostname" != *. && "$hostname" != *..* ]] || return 1
  IFS='.' read -r -a labels <<<"$hostname"
  for label in "${labels[@]}"; do
    [[ -n "$label" && "${#label}" -le 63 ]] || return 1
    [[ "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
  done
}

yatta_valid_username() {
  local username="$1"
  [[ "$username" != "root" ]] || return 1
  [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

yatta_current_timezone() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_TIMEZONE:-UTC}"
    return 0
  fi
  if yatta_command_exists timedatectl; then
    timedatectl show -p Timezone --value 2>/dev/null && return 0
  fi
  if [[ -r /etc/timezone ]]; then
    head -n 1 /etc/timezone
    return 0
  fi
  printf '%s\n' "未知"
}

yatta_timezone_available() {
  local timezone="$1"
  if [[ -z "$timezone" || "$timezone" == /* || "$timezone" == *..* ]]; then
    return 1
  fi
  if yatta_test_mode; then
    [[ "${YATTA_TEST_TIMEZONE_STATUS:-ok}" == "ok" ]]
    return $?
  fi
  if [[ -f "/usr/share/zoneinfo/${timezone}" ]]; then
    return 0
  fi
  yatta_command_exists timedatectl && timedatectl list-timezones 2>/dev/null | grep -Fx -- "$timezone" >/dev/null
}

yatta_user_exists() {
  local username="$1"
  if yatta_test_mode; then
    [[ " ${YATTA_TEST_EXISTING_USERS:-root} " == *" ${username} "* ]]
    return $?
  fi
  getent passwd "$username" >/dev/null 2>&1
}

yatta_user_in_group() {
  local username="$1"
  local group="$2"
  if yatta_test_mode; then
    [[ "$group" == "sudo" && " ${YATTA_TEST_SUDO_USERS:-root} " == *" ${username} "* ]]
    return $?
  fi
  id -nG "$username" 2>/dev/null | tr ' ' '\n' | grep -Fx -- "$group" >/dev/null
}

yatta_user_home() {
  local username="$1"
  if yatta_test_mode; then
    printf '/home/%s\n' "$username"
    return 0
  fi
  getent passwd "$username" | awk -F: '{ print $6; exit }'
}

yatta_list_normal_users() {
  if yatta_test_mode; then
    printf '%s\n' ${YATTA_TEST_NORMAL_USERS:-}
    return 0
  fi
  awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" { print $1 }' /etc/passwd
}

yatta_user_is_protected() {
  local username="$1"
  [[ -z "$username" ]] && return 0
  [[ "$username" == "root" ]] && return 0
  [[ -n "${YATTA_USER_NAME:-}" && "$username" == "$YATTA_USER_NAME" ]] && return 0
  [[ -n "${SUDO_USER:-}" && "$username" == "$SUDO_USER" ]] && return 0
  return 1
}

yatta_valid_ssh_public_key() {
  local key="$1"
  [[ "$key" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]]
}

yatta_package_installed() {
  local package="$1"
  if yatta_test_mode; then
    [[ " ${YATTA_TEST_INSTALLED_PACKAGES:-} " == *" ${package} "* ]]
    return $?
  fi
  dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fx "install ok installed" >/dev/null
}

yatta_missing_packages() {
  local package
  for package in "$@"; do
    if ! yatta_package_installed "$package"; then
      printf '%s\n' "$package"
    fi
  done
}

yatta_current_swap_bytes() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_SWAP_BYTES:-0}"
    return 0
  fi
  awk 'NR > 1 { total += $3 } END { printf "%.0f\n", total * 1024 }' /proc/swaps 2>/dev/null
}

yatta_memory_total_mb() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_MEMORY_MB:-2048}"
    return 0
  fi
  awk '/^MemTotal:/ { printf "%d\n", int($2 / 1024); exit }' /proc/meminfo 2>/dev/null
}

yatta_root_available_mb() {
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_ROOT_AVAILABLE_MB:-8192}"
    return 0
  fi
  df -Pm / 2>/dev/null | awk 'NR == 2 { print $4; exit }'
}

yatta_recommended_swap_mb() {
  local memory_mb="$1"
  local recommended
  if [[ ! "$memory_mb" =~ ^[0-9]+$ ]] || ((memory_mb <= 0)); then
    printf '%s\n' "1024"
    return 0
  fi
  recommended=$((memory_mb / 2))
  ((recommended < 1024)) && recommended=1024
  ((recommended > 4096)) && recommended=4096
  printf '%s\n' "$recommended"
}

yatta_valid_swap_size_mb() {
  local size_mb="$1"
  [[ "$size_mb" =~ ^[0-9]+$ ]] && ((size_mb >= 256 && size_mb <= 32768))
}

yatta_valid_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535))
}

yatta_detect_ssh_port() {
  local files=("/etc/ssh/sshd_config")
  local conf
  local detected
  if yatta_test_mode; then
    printf '%s\n' "${YATTA_TEST_SSH_PORT:-22}"
    return 0
  fi
  if yatta_command_exists sshd; then
    detected="$(sshd -T 2>/dev/null | awk '$1 == "port" && $2 ~ /^[0-9]+$/ { print $2; exit }')"
    if [[ -n "$detected" ]]; then
      printf '%s\n' "$detected"
      return 0
    fi
  fi
  if [[ -d /etc/ssh/sshd_config.d ]]; then
    for conf in /etc/ssh/sshd_config.d/*.conf; do
      [[ -e "$conf" ]] && files+=("$conf")
    done
  fi
  awk '
    {
      sub(/[[:space:]]*#.*/, "")
      if (tolower($1) == "port" && $2 ~ /^[0-9]+$/) {
        print $2
        exit
      }
    }
  ' "${files[@]}" 2>/dev/null | {
    IFS= read -r detected || detected=""
    if [[ -n "$detected" ]]; then
      printf '%s\n' "$detected"
    else
      printf '%s\n' "22"
    fi
  }
}

yatta_preflight() {
  if [[ -z "${BASH_VERSION:-}" ]]; then
    printf '%s\n' "Yatta 必须使用 Bash 运行，请执行：sudo bash yatta.sh" >&2
    return 1
  fi
  if ! yatta_is_root; then
    yatta_log_error "Yatta v1 必须以 root 身份运行。请执行：sudo bash yatta.sh"
    return 1
  fi
  if ! yatta_is_ubuntu; then
    yatta_log_error "Yatta v1 只支持 Ubuntu。当前系统不是受支持的 Ubuntu 环境。"
    return 1
  fi
  if ! yatta_apt_available; then
    yatta_log_error "缺少 apt/apt-get，无法按 Ubuntu 服务器初始化流程继续。"
    return 1
  fi
  if ! yatta_systemd_available; then
    yatta_log_error "未检测到可用 systemd，v1 需要 systemd 环境。"
    return 1
  fi
  yatta_log_ok "入口检查通过。"
}

yatta_system_summary() {
  if yatta_is_ubuntu; then
    printf 'Ubuntu\tok\t%s\n' "$(yatta_ubuntu_version)"
  else
    printf 'Ubuntu\terror\tv1 只支持 Ubuntu\n'
  fi

  if yatta_is_root; then
    printf 'root\tok\t当前以 root 身份运行\n'
  else
    printf 'root\terror\t请使用 sudo bash yatta.sh\n'
  fi

  if [[ -n "${BASH_VERSION:-}" ]]; then
    printf 'Bash\tok\t%s\n' "$(yatta_bash_version)"
  else
    printf 'Bash\terror\t需要 Bash 运行环境\n'
  fi

  if yatta_apt_available; then
    printf 'apt\tok\tapt 与 apt-get 可用\n'
  else
    printf 'apt\terror\t缺少 apt 或 apt-get\n'
  fi

  if yatta_systemd_available; then
    printf 'systemd\tok\tsystemctl 与运行目录可用\n'
  else
    printf 'systemd\terror\t未检测到可用 systemd\n'
  fi

  if yatta_network_status; then
    printf 'network\tok\t基础网络解析或连通性可用\n'
  else
    printf 'network\twarn\t暂未确认网络连通性，后续 apt 操作可能失败\n'
  fi
}
