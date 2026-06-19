#!/usr/bin/env bash
# 此文件由 yatta build 生成，请勿手写修改。

# 第一阶段刻意让 runtime 保持很小：此文件只是稳定锚点，
# 用于证明构建器能把 runtime 内容拼接进 yatta.sh。

yatta_runtime_main() {
  printf '%s\n' "Yatta Phase 1 runtime placeholder"
}


yatta_module_system_check_prompt() {
# 第一阶段占位脚本。第三阶段会收集并展示环境详情。
printf '%s\n' "plan: system-check placeholder"
}

yatta_module_system_check_apply() {
# 第一阶段占位脚本。第三阶段会实现真实环境检查。
printf '%s\n' "apply: system-check placeholder"
}

yatta_module_hostname_prompt() {
# 第一阶段占位脚本。第三阶段会询问是否保留或修改主机名。
printf '%s\n' "plan: hostname placeholder"
}

yatta_module_hostname_apply() {
# 第一阶段占位脚本。第三阶段会调用 hostname 适配器。
printf '%s\n' "apply: hostname placeholder"
}

yatta_module_user_prompt() {
# 第一阶段占位脚本。第三阶段会安全收集用户创建选项。
printf '%s\n' "plan: user placeholder"
}

yatta_module_user_apply() {
# 第一阶段占位脚本。第三阶段会调用用户管理适配器。
printf '%s\n' "apply: user placeholder"
}

yatta_module_timezone_prompt() {
# 第一阶段占位脚本。第三阶段会询问时区偏好。
printf '%s\n' "plan: timezone placeholder"
}

yatta_module_timezone_apply() {
# 第一阶段占位脚本。第三阶段会调用 timedatectl 适配器。
printf '%s\n' "apply: timezone placeholder"
}

yatta_module_packages_prompt() {
# 第一阶段占位脚本。第三阶段会登记软件包安装计划。
printf '%s\n' "plan: packages placeholder"
}

yatta_module_packages_apply() {
# 第一阶段占位脚本。第三阶段会调用 apt 适配器。
printf '%s\n' "apply: packages placeholder"
}

yatta_module_ufw_prompt() {
# 第一阶段占位脚本。第三阶段会收集 SSH 和 Web 端口选项。
printf '%s\n' "plan: ufw placeholder"
}

yatta_module_ufw_apply() {
# 第一阶段占位脚本。第三阶段会调用 UFW 适配器。
printf '%s\n' "apply: ufw placeholder"
}

