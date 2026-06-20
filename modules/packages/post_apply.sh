# apt upgrade 可能触发较大范围的软件包升级，所以只在用户明确确认后，
# 作为全部模块完成后的最后收尾任务执行。
if [[ "${YATTA_PACKAGES_APT_UPGRADE:-0}" != "1" ]]; then
  yatta_log_info "已跳过 apt upgrade 收尾任务。"
  return 0
fi

yatta_log_warn "即将执行 apt upgrade，这是本次脚本的最后收尾任务。"
yatta_apt_upgrade
