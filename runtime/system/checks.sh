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
