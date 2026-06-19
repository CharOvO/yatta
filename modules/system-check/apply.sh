# apply 阶段只做执行前最终确认，复用 runtime/system 的硬检查边界。
# 网络检查失败只提示风险，不阻断后续不依赖网络的模块。
yatta_preflight || return 1
if yatta_network_status; then
  yatta_log_ok "基础网络状态可用。"
else
  yatta_log_warn "暂未确认网络连通性，后续需要 apt 的模块可能失败。"
fi
