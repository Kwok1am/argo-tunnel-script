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

cloudflaredStatus="Uninstalled"
loginStatus="Unlogined"

[[ $EUID -ne 0 ]] && yellow "Please run this script as root user" && exit 1

[[ -z $(type -P curl) ]] && ${PACKAGE_UPDATE[int} && ${PACKAGE_INSTALL[int]} curl

archAffix() {
	case "$cpuArch" in
		i686 | i386) cpuArch='386' ;;
		x86_64 | amd64) cpuArch='amd64' ;;
		armv5tel | arm6l | armv7 | armv7l) cpuArch='arm' ;;
		armv8 | aarch64) cpuArch='aarch64' ;;
		*) red "CPU type not suported!" && exit 1 ;;
	esac
}

back2menu() {
	green "Process finished"
	read -p "Back to menu?[Y/n]" back2menuInput
	case "$back2menuInput" in
		n) exit 1 ;;
		*) menu ;;
	esac
}

checkStatus() {
	[[ -n $(cloudflared -help 2>/dev/null) ]] && cloudflaredStatus="Installed"
	[[ -f /root/.cloudflared/cert.pem ]] && loginStatus="Logined"
}

installCloudFlared() {
	wget -N https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpuArch
	mv cloudflared-linux-$cpuArch /usr/bin/cloudflared
	chmod +x /usr/bin/cloudflared
	[[ $loginStatus=="Unlogined" ]] && green "Please open the fllow link in your boweser and login your account:" && cloudflared tunnel login
	back2menu
}

uninstallCloudFlared() {
	[ $cloudflaredStatus == "Uninstalled" ] && red "You haven'tinstalled Cloudflared client" && exit 1
	rm -f /usr/bin/cloudflared
	rm -rf /root/.cloudflared
	green "CloudFlared client uninstalled sucessfully!"
}

makeTunnel() {
	read -p "Tunnel name:" tunnelName
	cloudflared tunnel create $tunnelName
	read -p "Domain: " tunnelDomain
	cloudflared tunnel route dns $tunnelName $tunnelDomain
	tunnelUUID=$( $(cloudflared tunnel list | grep $tunnelName) = /[0-9a-f\-]+/)
	read -p "Protocol(Default: http): " tunnelProtocol
	[ -z $tunnelProtocol ] && tunnelProtocol="http"
	read -p "Port(Default: 80): " tunnelPort
	[ -z $tunnelPort ] && tunnelPort=80
	read -p "Save file name(Default: $tunnelName)" tunnelFileName
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
	green "Config file saved to /root/$tunnelFileName.yml"
	back2menu
}

listTunnel() {
	[ $cloudflaredStatus == "Uninstalled" ] && red "You have to install Cloudflared client" && exit 1
	[ $loginStatus == "Unlogined" ] && red "You have to login Cloudflared client" && exit 1
	cloudflared tunnel list
	back2menu
}

runTunnel() {
	[ $cloudflaredStatus == "Uninstall" ] && red "You have to install Cloudflared client" && exit 1
	[ $loginStatus == "Unlogined" ] && red "You have to login Cloudflared client" && exit 1
	read -p "Config file path(E.g. /root/tunnel.yml): " ymlLocation
	cloudflared --config $ymlLocation service install
	systemctl enable cloudflared
	systemctl start cloudflared
	back2menu
}

killTunnel() {
	[ $cloudflaredStatus == "Uninstalled" ] && red "You have to install Cloudflared client" && exit 1
	[ $loginStatus == "Unlogined" ] && red "You have to login Cloudflared client" && exit 1
	systemctl stop cloudflared
	cloudflared service uninstall
	back2menu
}

deleteTunnel() {
	[ $cloudflaredStatus == "Uninstalled" ] && red "You have to install Cloudflared client" && exit 1
	[ $loginStatus == "Unlogined" ] && red "You have to login Cloudflared client" && exit 1
	read -p "Tunnel name: " tunnelName
	cloudflared tunnel delete $tunnelName
	back2menu
}

argoCert() {
	[ $cloudflaredStatus == "Uninstalled" ] && red "You have to install Cloudflared client" && exit 1
	[ $loginStatus == "Unloginec" ] && red "You have to login Cloudflared client" && exit 1
	sed -n "1, 5p" /root/.cloudflared/cert.pem >>/root/private.key
	sed -n "6, 24p" /root/.cloudflared/cert.pem >>/root/cert.crt
	green "Exported CloudFlare Argo Tunnel Cert sucessfully"
	yellow "Crt file: /root/cert.crt"
	yellow "Private key: /root/private.key"
	back2menu
}

menu() {
	clear
	checkStatus
	echo "CloudFlare Argo Tunnel Onekey Script"
	echo "fork from: Misaka's blog<https://owo.misaka.rest>"
	echo "edited by: yuuki410<tachibana@yuuki.eu.org> "
	echo "--------------------"
	echo "CloudFlared Client: $cloudflaredStatus"
	echo "Account authorizing: $loginStatus"
	echo "--------------------"
	echo "1. Install&Login/Update Cloudflared client"
	echo "2. Config Argo Tunnel"
	echo "3. List Argo Tunnels"
	echo "4. Install&Run Argo Tunnel as service"
	echo "5. Stop&Uninstall Argo Tunnel service"
	echo "6. Delete Argo Tunnel"
	echo "7. Export Argo Tunnel Cert"
	echo "8. Uninstall CloudFlared client"
	echo "9. Update this script"
	echo "0. Exit"
	echo "          "
	read -p "Choose:" menuNumberInput
	case "$menuNumberInput" in
		1) installCloudFlared ;;
		2) makeTunnel ;;
		3) listTunnel ;;
		4) runTunnel ;;
		5) killTunnel ;;
		6) deleteTunnel ;;
		7) argoCert ;;
		8) uninstallCloudFlared ;;
		9) wget -N https://raw.githubusercontent.com/yuuki410/argo-tunnel-script/master/argo.sh && bash argo.sh ;;
		*) exit 1 ;;
	esac
}

archAffix
checkCentOS8
menu
