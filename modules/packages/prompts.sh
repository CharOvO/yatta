# packages 模块只处理 v1 文档规定的基础包，扩展包留给后续模块。
YATTA_BASE_PACKAGES=(curl wget git vim unzip ca-certificates gnupg lsb-release)
YATTA_PACKAGES_MISSING=()
YATTA_PACKAGES_INSTALL="0"
YATTA_PACKAGES_APT_UPDATE="0"
YATTA_PACKAGES_APT_UPGRADE="0"

while IFS= read -r package; do
  [[ -n "$package" ]] && YATTA_PACKAGES_MISSING+=("$package")
done < <(yatta_missing_packages "${YATTA_BASE_PACKAGES[@]}")

if [[ "${#YATTA_PACKAGES_MISSING[@]}" -eq 0 ]]; then
  yatta_plan_add "packages" "ok" "基础软件包已全部安装。"
elif yatta_ui_confirm "检测到缺失基础软件包：${YATTA_PACKAGES_MISSING[*]}。是否安装？" "y"; then
  YATTA_PACKAGES_INSTALL="1"
  YATTA_PACKAGES_APT_UPDATE="1"
  yatta_plan_add "packages" "info" "将安装基础软件包：${YATTA_PACKAGES_MISSING[*]}"
else
  yatta_plan_add "packages" "warn" "跳过基础软件包安装，缺失：${YATTA_PACKAGES_MISSING[*]}"
fi

if yatta_ui_confirm "是否在脚本全部执行完成后运行 apt upgrade？这可能升级大量系统包。" "n"; then
  YATTA_PACKAGES_APT_UPDATE="1"
  YATTA_PACKAGES_APT_UPGRADE="1"
  yatta_plan_add "packages" "warn" "将在所有模块完成后执行 apt upgrade 作为最后收尾任务。"
else
  yatta_plan_add "packages" "info" "跳过 apt upgrade 收尾任务。"
fi
