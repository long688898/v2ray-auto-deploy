# v2ray-auto-deploy
# 脚本名称: auto_deploy.sh
# 功能: 自动部署 Sing-box，支持 VLESS+TCP+XTLS 和 VLESS+TCP+TLS
# 开源协议: 您可以选择一个开源协议，例如 MIT License
# 注意事项:
#   - 请使用 root 用户或具有 sudo 权限的用户运行此脚本。
#   - 在生产环境中使用前请务必进行充分的测试。
#   - 脚本假设您已经拥有有效的 TLS 证书 (fullchain.pem 和 private.key)。
#   - 请根据您的实际情况修改脚本中的配置，例如证书路径、监听端口等。
# ------------------------------------------------------------
通用引用方式（适用于大多数 Linux 和 macOS）：
使用 curl 下载并直接执行（不推荐在不信任的来源上这样做）：
bash <(curl -sSL https://raw.githubusercontent.com/long68898/v2ray-auto-deploy/main/auto_depl.sh)
