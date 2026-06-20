# SSH 配置生效可能影响当前远程连接，因此 main apply 不直接写入或 reload。
# prompt 阶段已经在主进程登记最终敏感操作，避免 TTY spinner 子进程丢失状态。
if ! declare -F yatta_ssh_hardening_has_changes >/dev/null 2>&1 || ! yatta_ssh_hardening_has_changes; then
  yatta_log_info "没有需要应用的 SSH 加固配置。"
  return 0
fi

yatta_log_warn "SSH 加固已延后到所有模块和收尾任务之后生效；若更换端口，最后 reload 时当前连接可能断开。"
