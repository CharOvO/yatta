# swap 模块只规划单个 swapfile。已有 swap 时默认不动，避免覆盖用户已有策略。
YATTA_SWAP_ACTION="skip"
YATTA_SWAP_PATH="/swapfile"
YATTA_SWAP_SIZE_MB="0"

YATTA_SWAP_CURRENT_BYTES="$(yatta_current_swap_bytes)"
YATTA_SWAP_MEMORY_MB="$(yatta_memory_total_mb)"
YATTA_SWAP_ROOT_AVAILABLE_MB="$(yatta_root_available_mb)"
YATTA_SWAP_RECOMMENDED_MB="$(yatta_recommended_swap_mb "$YATTA_SWAP_MEMORY_MB")"

if [[ "$YATTA_SWAP_CURRENT_BYTES" =~ ^[0-9]+$ ]] && ((YATTA_SWAP_CURRENT_BYTES > 0)); then
  yatta_plan_add "swap" "ok" "检测到系统已有 swap，跳过创建。"
else
  yatta_log_info "当前未检测到 swap；内存约 ${YATTA_SWAP_MEMORY_MB} MB，根分区可用约 ${YATTA_SWAP_ROOT_AVAILABLE_MB} MB。"
  choice="$(yatta_ui_select "swap 设置" 0 "创建推荐大小：${YATTA_SWAP_RECOMMENDED_MB} MB" "输入自定义大小" "跳过 swap 设置")"
  case "$choice" in
    创建推荐大小*)
      YATTA_SWAP_ACTION="create"
      YATTA_SWAP_SIZE_MB="$YATTA_SWAP_RECOMMENDED_MB"
      ;;
    输入自定义大小)
      while true; do
        YATTA_SWAP_SIZE_MB="$(yatta_ui_input "swap 大小（MB，256-32768）" "$YATTA_SWAP_RECOMMENDED_MB")"
        if yatta_valid_swap_size_mb "$YATTA_SWAP_SIZE_MB"; then
          YATTA_SWAP_ACTION="create"
          break
        fi
        yatta_log_warn "swap 大小必须是 256 到 32768 之间的整数 MB。"
      done
      ;;
  esac

  if [[ "$YATTA_SWAP_ACTION" == "create" ]]; then
    if [[ "$YATTA_SWAP_ROOT_AVAILABLE_MB" =~ ^[0-9]+$ ]] && ((YATTA_SWAP_ROOT_AVAILABLE_MB <= YATTA_SWAP_SIZE_MB + 256)); then
      yatta_log_warn "根分区可用空间不足以安全创建该 swapfile，已跳过。"
      YATTA_SWAP_ACTION="skip"
    fi
  fi

  if [[ "$YATTA_SWAP_ACTION" == "create" ]]; then
    yatta_plan_add "swap" "info" "将创建 ${YATTA_SWAP_PATH}，大小 ${YATTA_SWAP_SIZE_MB} MB，并写入 /etc/fstab。"
  else
    yatta_plan_add "swap" "info" "跳过 swap 设置。"
  fi
fi
