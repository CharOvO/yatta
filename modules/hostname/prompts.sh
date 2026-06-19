# hostname 模块只在询问阶段读取当前主机名并保存用户选择，真正修改留给 apply。
YATTA_HOSTNAME_CURRENT="$(yatta_current_hostname)"
YATTA_HOSTNAME_ACTION="keep"
YATTA_HOSTNAME_TARGET="$YATTA_HOSTNAME_CURRENT"

choice="$(yatta_ui_select "主机名设置" 0 "保留当前主机名：${YATTA_HOSTNAME_CURRENT}" "设置新的主机名")"
case "$choice" in
  设置新的主机名)
    while true; do
      YATTA_HOSTNAME_TARGET="$(yatta_ui_input "新的主机名" "$YATTA_HOSTNAME_CURRENT")"
      if yatta_valid_hostname "$YATTA_HOSTNAME_TARGET"; then
        YATTA_HOSTNAME_ACTION="set"
        break
      fi
      yatta_log_warn "主机名只能包含字母、数字、短横线和点，且每段不能以短横线开头或结尾。"
    done
    ;;
esac

if [[ "$YATTA_HOSTNAME_ACTION" == "keep" ]]; then
  yatta_plan_add "hostname" "ok" "保留当前主机名：${YATTA_HOSTNAME_CURRENT}"
elif [[ "$YATTA_HOSTNAME_TARGET" == "$YATTA_HOSTNAME_CURRENT" ]]; then
  yatta_plan_add "hostname" "ok" "目标主机名已是当前值：${YATTA_HOSTNAME_TARGET}"
else
  yatta_plan_add "hostname" "info" "将主机名设置为：${YATTA_HOSTNAME_TARGET}"
fi
