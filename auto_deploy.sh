#!/bin/bash

# -----------------------------------------------------------------------------
# 脚本名称: auto_deploy_singbox.sh
# 功能: 自动部署 Sing-box，支持 VLESS+TCP+XTLS 和 VLESS+TCP+TLS
# 作者: 您可以署名
# 开源协议: 您可以选择一个开源协议，例如 MIT License
# 注意事项:
#   - 请使用 root 用户或具有 sudo 权限的用户运行此脚本。
#   - 在生产环境中使用前请务必进行充分的测试。
#   - 脚本假设您已经拥有有效的 TLS 证书 (fullchain.pem 和 private.key)。
#   - 请根据您的实际情况修改脚本中的配置，例如证书路径、监听端口等。
# -----------------------------------------------------------------------------

# 定义 Sing-box 版本 (可以设置为 "latest" 或指定版本号)
singbox_version="latest"

# 定义配置文件目录和文件名
config_dir="/etc/sing-box"
config_file="$config_dir/config.json"

# 定义 Systemd 服务名称
service_name="singbox"
service_file="/etc/systemd/system/$service_name.service"

# -------------------- 函数定义 --------------------

# 检查是否以 root 用户或具有 sudo 权限运行
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "错误: 请使用 root 用户或具有 sudo 权限的用户运行此脚本。"
    exit 1
  fi
}

# 获取操作系统信息
get_os_info() {
  os_info=$(uname -s)
  os_version=$(uname -r)
  arch=$(uname -m)
  echo "当前操作系统: $os_info $os_version ($arch)"
}

# 安装常用依赖
install_dependencies() {
  echo "安装常用依赖..."
  if [[ "$os_info" == "Linux" ]]; then
    if command -v apt-get &> /dev/null; then
      sudo apt-get update
      sudo apt-get install -y curl wget unzip systemd
    elif command -v yum &> /dev/null; then
      sudo yum update -y
      sudo yum install -y curl wget unzip systemd
    elif command -v dnf &> /dev/null; then
      sudo dnf update -y
      sudo dnf install -y curl wget unzip systemd
    else
      echo "警告: 未检测到 apt, yum 或 dnf，请手动安装 curl, wget, unzip, systemd。"
    fi
  else
    echo "警告: 非 Linux 操作系统，请手动安装相关依赖。"
  fi
  echo "依赖安装完成。"
}

# 下载和安装 Sing-box
install_singbox() {
  echo "下载和安装 Sing-box..."
  case "$arch" in
    x86_64) singbox_arch="amd64" ;;
    aarch64) singbox_arch="arm64" ;;
    armv7l) singbox_arch="armv7" ;;
    *)
      echo "错误: 不支持的 CPU 架构: $arch"
      exit 1
      ;;
  esac

  download_url="https://github.com/SagerNet/sing-box/releases/$singbox_version/sing-box-$singbox_version-linux-$singbox_arch.zip"
  binary_name="sing-box"
  install_path="/usr/local/bin/$binary_name"

  echo "下载 Sing-box..."
  curl -L "$download_url" -o /tmp/sing-box.zip
  if [ $? -ne 0 ]; then
    echo "错误: 下载 Sing-box 失败。"
    exit 1
  fi

  echo "解压 Sing-box..."
  sudo unzip /tmp/sing-box.zip -d /tmp/sing-box-extracted
  if [ $? -ne 0 ]; then
    echo "错误: 解压 Sing-box 失败。"
    exit 1
  fi

  echo "移动 Sing-box 到 $install_path..."
  sudo mv /tmp/sing-box-extracted/$binary_name "$install_path"
  sudo chmod +x "$install_path"
  if [ $? -ne 0 ]; then
    echo "错误: 移动 Sing-box 失败。"
    exit 1
  fi

  echo "Sing-box 安装完成，路径: $install_path"
  rm -rf /tmp/sing-box.zip /tmp/sing-box-extracted
}

# 生成 Sing-box 配置文件
generate_config() {
  echo "生成 Sing-box 配置文件..."
  sudo mkdir -p "$config_dir"

  echo "请选择要部署的协议："
  echo "1. VLESS+TCP+XTLS"
  echo "2. VLESS+TCP+TLS"
  read -p "请输入选项 (1 或 2): " protocol_choice

  uuid=$(uuidgen)
  echo "生成的 UUID: $uuid"

  read -p "请输入监听端口 (默认为 443): " listen_port
  listen_port=${listen_port:-443}

  read -p "请输入 TLS 证书文件路径 (fullchain.pem): " cert_path
  read -p "请输入 TLS 私钥文件路径 (private.key): " key_path

  if [[ "$protocol_choice" -eq 1 ]]; then
    cat > "$config_file" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $listen_port,
      "tag": "vless-inbound",
      "server_settings": {
        "clients": [
          {
            "id": "$uuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "stream_settings": {
        "network": "tcp",
        "security": "xtls",
        "xtls_settings": {
          "alpn": [
            "http/1.1"
          ],
          "server": true,
          "certificates": [
            {
              "certificate_file": "$cert_path",
              "key_file": "$key_path"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    echo "VLESS+TCP+XTLS 配置文件已生成: $config_file"
  elif [[ "$protocol_choice" -eq 2 ]]; then
    cat > "$config_file" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "0.0.0.0",
      "listen_port": $listen_port,
      "tag": "vless-inbound",
      "server_settings": {
        "clients": [
          {
            "id": "$uuid"
          }
        ],
        "decryption": "none"
      },
      "stream_settings": {
        "network": "tcp",
        "security": "tls",
        "tls_settings": {
          "alpn": [
            "http/1.1"
          ],
          "server": true,
          "certificates": [
            {
              "certificate_file": "$cert_path",
              "key_file": "$key_path"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    echo "VLESS+TCP+TLS 配置文件已生成: $config_file"
  else
    echo "错误: 无效的选项。"
    exit 1
  fi
}

# 配置 Systemd 服务
configure_systemd() {
  echo "配置 Systemd 服务..."
  cat > "$service_file" <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
User=root
WorkingDirectory=$config_dir
ExecStart=/usr/local/bin/sing-box run -c $config_file
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable "$service_name"
  sudo systemctl start "$service_name"

  if [ $? -eq 0 ]; then
    echo "Sing-box 服务已启动。"
    echo "可以使用命令 'systemctl status $service_name' 查看服务状态。"
  else
    echo "错误: 启动 Sing-box 服务失败。"
  fi
}

# 配置防火墙
configure_firewall() {
  echo "配置防火墙..."
  if command -v ufw &> /dev/null; then
    sudo ufw allow "$listen_port"/tcp
    sudo ufw enable
    echo "已使用 ufw 开放端口 $listen_port/tcp。"
  elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port="$listen_port/tcp"
    sudo firewall-cmd --reload
    echo "已使用 firewalld 开放端口 $listen_port/tcp。"
  else
    echo "警告: 未检测到 ufw 或 firewalld，请手动配置防火墙开放端口 $listen_port/tcp。"
  fi
}

# 输出部署信息
output_info() {
  echo ""
  echo "-------------------- 部署完成 --------------------"
  echo "服务器 IP 地址: $(curl -s ifconfig.me)"
  echo "监听端口: $listen_port"
  echo "UUID: $uuid"
  echo ""
  echo "请在您的客户端配置中填写以上信息。"
  echo ""
  echo "VLESS 配置示例 (请根据您的客户端进行调整):"
  echo "协议: vless"
  echo "地址: $(curl -s ifconfig.me)"
  echo "端口: $listen_port"
  echo "UUID: $uuid"
  echo "传输协议: tcp"
  if [[ "$protocol_choice" -eq 1 ]]; then
    echo "加密方式: xtls-rprx-vision"
  elif [[ "$protocol_choice" -eq 2 ]]; then
    echo "加密方式: tls"
    echo "TLS 域名 (SNI): (通常与您的证书域名一致)"
  fi
  echo ""
  echo "配置文件路径: $config_file"
  echo "Sing-box 服务管理命令："
  echo "  sudo systemctl start singbox"
  echo "  sudo systemctl stop singbox"
  echo "  sudo systemctl restart singbox"
  echo "  sudo systemctl status singbox"
  echo "  sudo journalctl -u singbox -f"
  echo ""
  echo "-------------------------------------------------"
}

# -------------------- 主流程 --------------------

check_root
get_os_info
install_dependencies
install_singbox
generate_config
configure_systemd
configure_firewall
output_info

echo "脚本执行完毕。"

exit 0
