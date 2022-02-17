#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#================================================================
#	System Required: CentOS 6/7/8,Debian 8/9/10,Ubuntu 16/18/20
#	Description: Easy Ehco Script For Landing Server
#	Version: 1.0
#	Author: Vincent Young
# 	Telegram: https://t.me/missuo
#	Github: https://github.com/missuo/Ehcoo
#	Latest Update: June 27, 2021
#=================================================================

cur_dir=`pwd`

#获取键盘输入
get_char(){
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty $SAVEDSTTY
}

#定义一些颜色
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#确保本脚本在ROOT下运行
[[ $EUID -ne 0 ]] && echo -e "[${red}错误${plain}]请以ROOT运行本脚本！" && exit 1

check_sys(){
	echo "现在开始检查你的系统是否支持"
	#判断是什么Linux系统
	if [[ -f /etc/redhat-release ]]; then
		release="Centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="Debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="Ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="Centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="Debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="Ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="Centos"
	fi
	
	#判断Linux系统的具体版本和位数
	if [[ -s /etc/redhat-release ]]; then
		version=`grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1`
	else
		version=`grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1`
	fi
	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="x64"
	else
		bit="x32"
	fi
	
	#判断内核版本
	kernel_version=`uname -r | awk -F "-" '{print $1}'`
	kernel_version_full=`uname -r`
	net_congestion_control=`cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}'`
	net_qdisc=`cat /proc/sys/net/core/default_qdisc | awk '{print $1}'`
	kernel_version_r=`uname -r | awk '{print $1}'`
	echo "系统版本为: $release $version $bit 内核版本为: $kernel_version_r"
	
	if [ $release = "Centos" ]
	then
		yum -y install wget jq
		sysctl_dir="/usr/lib/systemd/system/"
		full_sysctl_dir=${sysctl_dir}"ehco.service"
	elif [ $release = "Debian" ]
	then
		apt-get install wget jq -y
		sysctl_dir="/etc/systemd/system/"
		full_sysctl_dir=${sysctl_dir}"ehco.service"
	elif [ $release = "Ubuntu" ]
	then
		apt-get install wget jq -y
		sysctl_dir="/lib/systemd/system/"
		full_sysctl_dir=${sysctl_dir}"ehco.service"
	else
		echo -e "[${red}错误${plain}]不支持当前系统"
		exit 1
	fi
}
check_sys

landing_config(){
	clear
	echo "现在开始配置落地鸡"
	echo ""
	read -p "请输入落地鸡需要监听的本地端口(比如SS、V2Ray的端口):" server_port
	[ -z "${server_port}" ]
	echo ""
	read -p "请输入落地鸡隧道的端口(用于和中转鸡通信，建议443/8443):" listen_port
	[ -z "${listen_port}" ]
	echo ""
	if [ ! -f $full_sysctl_dir ]; then
		wget https://cdn.jsdelivr.net/gh/missuo/Ehcoo/ehco-landing.service -O ehco.service
		mv ehco.service $sysctl_dir
	fi
	sed -i 's/'443'/'${listen_port}'/g' $full_sysctl_dir
	sed -i 's/'1111'/'${server_port}'/g' $full_sysctl_dir
	echo "正在本机启动Echo隧道"
	systemctl daemon-reload
	systemctl start ehco.service
	systemctl enable ehco.service
	echo ""
	clear
	echo "启动成功并已设定为开机自启。Ehco隧道的通信端口为 ${listen_port} 请断开SSH连接，开始中转鸡的配置吧！"
	echo "Have a nice day:)"
}

forward_config(){
	clear
	echo "现在开始配置落地鸡"
	echo ""
	echo "第二次执行代表添加第二个隧道中转"
	read -p "请输入落地鸡的IP地址或者域名:" ip
	[ -z "${ip}" ]
	echo ""
	read -p "请输入落地鸡的通信端口:" landing_port
	[ -z "${landing_port}" ]
	echo ""
	read -p "请输入本机的中转/监听端口(任意未被占用的端口即可):" local_port
	[ -z "${local_port}" ]
	echo ""
	if [ ! -f "/root/ehco.json" ]; then
		wget https://cdn.jsdelivr.net/gh/missuo/Ehcoo/ehco.json -O ehco.json
	fi
	JSON='{"listen":"0.0.0.0:local_port","listen_type":"raw","transport_type":"ws","tcp_remotes":["wss://ip:landing_port"],"udp_remotes":["ip:landing_port"]}'
	JSON=${JSON/local_port/$local_port};
	JSON=${JSON/landing_port/$landing_port};
	JSON=${JSON/landing_port/$landing_port};
	JSON=${JSON/ip/$ip};
	JSON=${JSON/ip/$ip};
	temp=`jq --argjson groupInfo $JSON '.relay_configs += [$groupInfo]' ehco.json`
	echo $temp > ehco.json
	if [ ! -f $full_sysctl_dir ]; then
		wget https://cdn.jsdelivr.net/gh/missuo/Ehcoo/ehco-forward.service -O ehco.service
		mv ehco.service $sysctl_dir
	fi
	echo "正在本机启动Echo隧道"
	systemctl daemon-reload
	systemctl start ehco.service
	systemctl enable ehco.service
	systemctl restart ehco.service
	echo ""
	clear
	echo "启动成功并已设定为开机自启。Ehco隧道的连接端口为 ${local_port} ！"
	echo "请勿移动ROOT目录下的ehco.json文件，非常会导致严重错误！"
	echo "Have a nice day:)"
}

if [ ! -f "/usr/bin/ehco" ]; then
	echo -e "现在开始安装Ehco隧道"
	wget https://cdn.jsdelivr.net/gh/missuo/Ehcoo/ehco_1.0.7_linux_amd64 -O ehco
	chmod +x ehco
	mv ehco /usr/bin
fi
echo "恭喜你，Echo已经安装完毕，现在开始配置并启动Echo服务"
echo ""
start_menu(){
		clear
		echo && echo -e "Echo隧道便携脚本 Made by missuo
更新内容及反馈： https://github.com/missuo/Ehcoo
————————————模式选择————————————
${green}1.${plain} 配置落地机器
${green}2.${plain} 配置中转机器
${green}3.${plain} 永久关闭
${green}4.${plain} 重新启用
${green}5.${plain} 重启隧道
${green}0.${plain} 退出脚本
————————————————————————————————"
	read -p "请输入数字: " num
	case "$num" in
	1)
		landing_config
		;;
	2)
		forward_config
		;;
	3)
		systemctl stop ehco.service
		systemctl disable ehco.service
		;;
	4)
		systemctl start ehco.service
		systemctl enable ehco.service
		;;
	5)
		systemctl restart ehco.service
		;;
	0)
		exit 1
		;;
	*)
		clear
		echo -e "[${red}错误${plain}]:请输入正确数字[0-5]"
		sleep 5s
		start_menu
		;;
	esac
}
start_menu 
