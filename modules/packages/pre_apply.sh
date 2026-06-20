# packages 的前置阶段只负责刷新 apt 索引。这样后续需要安装软件包的模块
# 可以复用较新的包索引，同时把风险更高的 apt upgrade 留到最终收尾阶段。
if [[ "${YATTA_PACKAGES_APT_UPDATE:-0}" != "1" ]]; then
  yatta_log_info "没有需要提前刷新的 apt 索引。"
  return 0
fi

yatta_apt_update
