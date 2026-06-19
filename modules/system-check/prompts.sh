# system-check 在 Phase 2 负责展示环境摘要，并把前置检查登记到执行计划。
# 入口硬阻断仍由 runtime/system 完成，这里只复用探测函数，不重复散落检查逻辑。
printf '%-12s %-8s %s\n' "项目" "状态" "说明" >&2
printf '%-12s %-8s %s\n' "------------" "--------" "------------------------------" >&2
while IFS=$'\t' read -r item status detail; do
  printf '%-12s %-8s %s\n' "$item" "$status" "$detail" >&2
  yatta_plan_add "system-check" "$status" "检查 ${item}：${detail}"
done < <(yatta_system_summary)
