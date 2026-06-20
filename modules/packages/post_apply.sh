# apt upgrade 可能触发较大范围的软件包升级，所以只在用户明确确认后，
# 作为常规模块完成后的收尾任务执行；远程访问类最终操作会排在它之后。
if [[ "${YATTA_PACKAGES_APT_UPGRADE:-0}" != "1" ]]; then
  yatta_log_info "已跳过 apt upgrade 收尾任务。"
  return 0
fi

yatta_log_warn "即将执行 apt upgrade，这是 packages 模块的收尾任务。"
yatta_apt_upgrade
