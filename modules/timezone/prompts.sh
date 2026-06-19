# timezone 模块只保存时区选择，实际 timedatectl 修改在 apply 阶段完成。
YATTA_TIMEZONE_CURRENT="$(yatta_current_timezone)"
YATTA_TIMEZONE_ACTION="set"
YATTA_TIMEZONE_TARGET="Asia/Shanghai"

choice="$(yatta_ui_select "时区设置" 0 "设置为 Asia/Shanghai" "输入其他时区" "跳过时区设置")"
case "$choice" in
  输入其他时区)
    while true; do
      YATTA_TIMEZONE_TARGET="$(yatta_ui_input "时区名称" "$YATTA_TIMEZONE_CURRENT")"
      if yatta_timezone_available "$YATTA_TIMEZONE_TARGET"; then
        break
      fi
      yatta_log_warn "未找到该时区，请使用类似 Asia/Shanghai 的 IANA 时区名称。"
    done
    ;;
  跳过时区设置)
    YATTA_TIMEZONE_ACTION="skip"
    ;;
esac

if [[ "$YATTA_TIMEZONE_ACTION" == "skip" ]]; then
  yatta_plan_add "timezone" "ok" "跳过时区设置，当前时区：${YATTA_TIMEZONE_CURRENT}"
elif [[ "$YATTA_TIMEZONE_TARGET" == "$YATTA_TIMEZONE_CURRENT" ]]; then
  yatta_plan_add "timezone" "ok" "时区已是期望值：${YATTA_TIMEZONE_TARGET}"
else
  yatta_plan_add "timezone" "info" "将时区设置为：${YATTA_TIMEZONE_TARGET}"
fi
