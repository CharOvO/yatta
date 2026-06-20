# apply 阶段重新检查 swap 状态，避免重复创建或覆盖已有策略。
if [[ "${YATTA_SWAP_ACTION:-skip}" != "create" ]]; then
  yatta_log_info "已跳过 swap 设置。"
  return 0
fi

if ! yatta_valid_swap_size_mb "${YATTA_SWAP_SIZE_MB:-}"; then
  yatta_log_error "swap 大小无效，已停止。"
  return 1
fi

current_swap_bytes="$(yatta_current_swap_bytes)"
if [[ "$current_swap_bytes" =~ ^[0-9]+$ ]] && ((current_swap_bytes > 0)); then
  yatta_log_ok "系统已存在 swap，跳过创建。"
  return 0
fi

available_mb="$(yatta_root_available_mb)"
if [[ "$available_mb" =~ ^[0-9]+$ ]] && ((available_mb <= YATTA_SWAP_SIZE_MB + 256)); then
  yatta_log_error "根分区可用空间不足，无法安全创建 ${YATTA_SWAP_SIZE_MB} MB swapfile。"
  return 1
fi

swap_path="${YATTA_SWAP_PATH:-/swapfile}"
fstab_line="${swap_path} none swap sw 0 0"

if swapon --show=NAME --noheadings 2>/dev/null | grep -Fx -- "$swap_path" >/dev/null; then
  yatta_log_ok "swapfile 已启用：${swap_path}"
else
  if [[ -e "$swap_path" ]]; then
    yatta_log_warn "swapfile 路径已存在，将尝试直接启用：${swap_path}"
  elif yatta_command_exists fallocate; then
    yatta_run_command fallocate -l "${YATTA_SWAP_SIZE_MB}M" "$swap_path" || return 1
  else
    yatta_run_command dd if=/dev/zero of="$swap_path" bs=1M count="$YATTA_SWAP_SIZE_MB" status=progress || return 1
  fi

  yatta_run_command chmod 0600 "$swap_path" || return 1
  yatta_run_command mkswap "$swap_path" || return 1
  yatta_run_command swapon "$swap_path" || return 1
fi

if [[ -r /etc/fstab ]] && grep -Fx -- "$fstab_line" /etc/fstab >/dev/null 2>&1; then
  yatta_log_ok "fstab 已包含 swapfile 配置。"
elif yatta_dry_run; then
  yatta_log_info "[dry-run] append to /etc/fstab: ${fstab_line}"
else
  printf '%s\n' "$fstab_line" >>/etc/fstab
fi
