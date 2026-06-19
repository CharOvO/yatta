# apply 阶段重新计算缺失包，避免重复运行时重新安装已满足的软件包。
if [[ "${YATTA_PACKAGES_INSTALL:-0}" != "1" ]]; then
  yatta_log_warn "已跳过基础软件包安装。"
  return 0
fi

fresh_missing=()
while IFS= read -r package; do
  [[ -n "$package" ]] && fresh_missing+=("$package")
done < <(yatta_missing_packages "${YATTA_BASE_PACKAGES[@]}")

if [[ "${#fresh_missing[@]}" -eq 0 ]]; then
  yatta_log_ok "基础软件包已全部安装。"
  return 0
fi

yatta_apt_update || return 1
yatta_apt_install_missing "${fresh_missing[@]}"
