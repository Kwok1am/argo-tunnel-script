#!/bin/bash

red() {
	echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
	echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
	echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Alpine")
PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove")

cpuArch=$(uname -m)

cloudflaredStatus="未安装"
loginStatus="未登录"

[[ $EUID -ne 0 ]] && yellow "请以 root 用户运行此脚本" && exit 1

[[ -z $(type -P curl) ]] && ${PACKAGE_UPDATE[int} && ${PACKAGE_INSTALL[int]} curl

archAffix() {
	case "$cpuArch" in
		i686 | i386) cpuArch='386' ;;
		x86_64 | amd64) cpuArch='amd64' ;;
		armv5tel | arm6l | armv7 | armv7l) cpuArch='arm' ;;
		armv8 | aarch64) cpuArch='aarch64' ;;
		*) red "不支持的 CPU 类型!" && exit 1 ;;
	esac
}

back2menu() {
	green "操作完成"
	read -p "返回菜单?[Y/n]" back2menuInput
	case "$back2menuInput" in
		n) exit 1 ;;
		*) menu ;;
	esac
}

checkStatus() {
	[[ -n $(cloudflared -help 2>/dev/null) ]] && cloudflaredStatus="已安装"
	[[ -f /root/.cloudflared/cert.pem ]] && loginStatus="已登录"
}

installCloudFlared() {
	wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpuArch
	mv cloudflared-linux-$cpuArch /usr/bin/cloudflared
	chmod +x /usr/bin/cloudflared
	[[ $loginStatus=="未登录" ]] && cloudflared tunnel login
	back2menu
}

uninstallCloudFlared() {
	[ $cloudflaredStatus == "未安装" ] && red "你尚未安装 Cloudflared 客户端" && exit 1
	rm -f /usr/bin/cloudflared
	rm -rf /root/.cloudflared
	green "CloudFlared 客户端卸载成功!"
}

makeTunnel() {
	read -p "隧道名称:" tunnelName
	cloudflared tunnel create $tunnelName
	read -p "域名: " tunnelDomain
	cloudflared tunnel route dns $tunnelName $tunnelDomain
	tunnelUUID=$( $(cloudflared tunnel list | grep $tunnelName) = /[0-9a-f\-]+/)
	read -p "协议(默认: http): " tunnelProtocol
	[ -z $tunnelProtocol ] && tunnelProtocol="http"
	read -p "端口(默认: 80): " tunnelPort
	[ -z $tunnelPort ] && tunnelPort=80
	read -p "保存文件名(默认: $tunnelName)" tunnelFileName
	[ -z $tunnelFileName ] && tunnelFileName = $tunnelName
	cat <<EOF >~/$tunnelFileName.yml
tunnel: $tunnelName
credentials-file: /root/.cloudflared/$tunnelUUID.json
originRequest:
  connectTimeout: 30s
  noTLSVerify: true
ingress:
  - hostname: $tunnelDomain
    service: $tunnelProtocol://localhost:$tunnelPort
  - service: http_status:404
EOF
	green "配置文件已保存到 /root/$tunnelFileName.yml"
	back2menu
}

listTunnel() {
	[ $cloudflaredStatus == "未安装" ] && red "你必须安装 Cloudflared 客户端" && exit 1
	[ $loginStatus == "未登录" ] && red "你必须登录 Cloudflared 客户端" && exit 1
	cloudflared tunnel list
	back2menu
}

runTunnel() {
	[ $cloudflaredStatus == "未安装" ] && red "你必须安装 Cloudflared 客户端" && exit 1
	[ $loginStatus == "未登录" ] && red "你必须登录 Cloudflared 客户端" && exit 1
	read -p "配置文件路径(例如: /root/tunnel.yml): " ymlLocation
	cloudflared --config $ymlLocation service install
	systemctl enable cloudflared
	systemctl start cloudflared
	back2menu
}

restartTunnel() {
	[ $cloudflaredStatus == "未安装" ] && red "你必须安装 Cloudflared 客户端" && exit 1
	[ $loginStatus == "未登录" ] && red "你必须登录 Cloudflared 客户端" && exit 1
	systemctl restart cloudflared
	back2menu
}

killTunnel() {
	[ $cloudflaredStatus == "未安装" ] && red "你必须安装 Cloudflared 客户端" && exit 1
	[ $loginStatus == "未登录" ] && red "你必须登录 Cloudflared 客户端" && exit 1
	systemctl stop cloudflared
	cloudflared service uninstall
	back2menu
}

deleteTunnel() {
	[ $cloudflaredStatus == "未安装" ] && red "你必须安装 Cloudflared 客户端" && exit 1
	[ $loginStatus == "未登录" ] && red "你必须登录 Cloudflared 客户端" && exit 1
	read -p "隧道名称: " tunnelName
	cloudflared tunnel delete $tunnelName
	back2menu
}

argoCert() {
	[ $cloudflaredStatus == "未安装" ] && red "你必须安装 Cloudflared 客户端" && exit 1
	[ $loginStatus == "未登录" ] && red "你必须登录 Cloudflared 客户端" && exit 1
	sed -n "1, 5p" /root/.cloudflared/cert.pem >>/root/private.key
	sed -n "6, 24p" /root/.cloudflared/cert.pem >>/root/cert.crt
	green "成功导出 CloudFlare Argo Tunnel 证书"
	yellow "证书文件: /root/cert.crt"
	yellow "私钥文件: /root/private.key"
	back2menu
}

menu() {
	clear
	checkStatus
	echo "CloudFlare Argo Tunnel 一键脚本"
	echo ""
	echo "--------------------"
	echo "CloudFlared 客户端: $cloudflaredStatus"
	echo "账户授权状态: $loginStatus"
	echo "--------------------"
	echo ""
	echo "1.  安装&登录/更新 Cloudflared 客户端"
	echo "2.  配置 Argo Tunnel"
	echo "3.  列出 Argo Tunnels"
	echo "4.  作为服务安装&运行 Argo Tunnel"
	echo "5.  重启 Argo Tunnel 服务"
	echo "6.  停止&卸载 Argo Tunnel 服务"
	echo "7.  删除 Argo Tunnel"
	echo "8.  导出 Argo Tunnel 证书"
	echo "9.  卸载 CloudFlared 客户端"
	echo "10. 更新此脚本"
	echo "0.  退出"
	echo "          "
	read -p "选择:" menuNumberInput
	case "$menuNumberInput" in
		1) installCloudFlared ;;
		2) makeTunnel ;;
		3) listTunnel ;;
		4) runTunnel ;;
		5) restartTunnel ;;
		6) killTunnel ;;
		7) deleteTunnel ;;
		8) argoCert ;;
		9) uninstallCloudFlared ;;
		10) wget -N https://raw.githubusercontent.com/Kwok1am/argo-tunnel-script/master/argo.sh && bash argo.sh ;;
		*) exit 1 ;;
	esac
}

archAffix
checkCentOS8
menu
