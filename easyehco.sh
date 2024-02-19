###
 # @Author: Vincent Young
 # @Date: 2024-02-19 11:06:56
 # @LastEditors: Vincent Young
 # @LastEditTime: 2024-02-19 11:36:52
 # @FilePath: /EasyEhco/easyehco.sh
 # @Telegram: https://t.me/missuo
 # @GitHub: https://github.com/missuo
 # 
 # Copyright © 2024 by Vincent, All Rights Reserved. 
### 

# Define colors
red='\033[0;31m'

# Ensure this script runs as ROOT
if [[ $EUID -ne 0 ]]; then
    echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1
fi

check_sys(){
    echo "Starting system support check..."
    # Determine the Linux distribution
    if [[ -f /etc/redhat-release ]]; then
        release="Centos"
    elif grep -q -E -i "debian" /etc/issue; then
        release="Debian"
    elif grep -q -E -i "ubuntu" /etc/issue; then
        release="Ubuntu"
    elif grep -q -E -i "centos|red hat|redhat" /etc/issue; then
        release="Centos"
    elif grep -q -E -i "debian" /proc/version; then
        release="Debian"
    elif grep -q -E -i "ubuntu" /proc/version; then
        release="Ubuntu"
    elif grep -q -E -i "centos|red hat|redhat" /proc/version; then
        release="Centos"
    fi
    
    # Determine the specific version and architecture of the Linux distribution
    if [[ -s /etc/redhat-release ]]; then
        version=$(grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1)
    else
        version=$(grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1)
    fi
    bit=$(uname -m)
    if [[ ${bit} = "x86_64" ]]; then
        bit="x64"
    else
        bit="x32"
    fi
    
    # Check kernel version
    kernel_version=$(uname -r | awk -F "-" '{print $1}')
    kernel_version_full=$(uname -r)
    net_congestion_control=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
    net_qdisc=$(cat /proc/sys/net/core/default_qdisc | awk '{print $1}')
    kernel_version_r=$(uname -r | awk '{print $1}')
    echo "System version: $release $version $bit Kernel version: $kernel_version_r"
    
    # Additional check for CentOS version to decide between yum or dnf
    if [ "$release" = "Centos" ]; then
        if [ "$version" -ge 8 ]; then
            dnf -y install wget jq
        else
            yum -y install wget jq
        fi
    elif [ "$release" = "Debian" ]; then
        apt-get install wget jq -y
    elif [ "$release" = "Ubuntu" ]; then
        apt-get install wget jq -y
    else
        echo -e "[${red}Error${plain}] Your system is not supported."
        exit 1
    fi
}
check_sys

landing_config(){
    install
    clear
    echo "Starting the configuration of the landing server now."
    echo ""
    read -p "Please enter the local port the landing server needs to listen on (e.g., port for SS, V2Ray): " server_port
    [ -z "${server_port}" ]
    echo ""
    while true; do
        read -p "Please enter the tunnel port for the landing server (used for communication with the relay server, recommended 443/8443): " listen_port
        if lsof -Pi :$listen_port -sTCP:LISTEN -t >/dev/null ; then
            echo "Port $listen_port is already in use. Please choose a different port."
        else
            [ -z "${listen_port}" ] && continue
            break
        fi
    done
    echo ""
    read -p "Please enter the forwarding mode (r/ws/wss/mwss): " forward_mode
    case $forward_mode in
        r|ws|wss|mwss)
            ;;
        *)
            echo "Invalid forwarding mode. Please enter one of the following: r, ws, wss, mwss."
            exit 1
            ;;
    esac
    if [ ! -f /etc/systemd/system/ehco.service ]; then
        wget https://cdn.jsdelivr.net/gh/missuo/EasyEhco/ehco-landing.service -O ehco.service
        mv ehco.service /etc/systemd/system/
    fi
    sed -i "s/%p/$server_port/g" /etc/systemd/system/ehco.service
    sed -i "s/%i/$listen_port/g" /etc/systemd/system/ehco.service
    sed -i "s/%f/$forward_mode/g" /etc/systemd/system/ehco.service
    echo "Starting the Ehco tunnel on this server."
    systemctl daemon-reload
    systemctl start ehco.service
    systemctl enable ehco.service
    echo ""
    clear
    echo "The startup was successful, and the service has been set to start at boot. The Ehco tunnel's communication port is ${listen_port}, using ${forward_mode} forwarding mode. Please disconnect the SSH connection and start configuring the relay server!"
    echo "Have a nice day :)"
}

forward_config(){
    install
    clear
    echo "Starting the configuration of the relay server."
    echo ""
    echo "Executing this script a second time will add a second relay tunnel."
    
    read -p "Please enter the IP address or domain name of the landing server: " ip
    [ -z "${ip}" ]
    echo ""
    
    read -p "Please enter the communication port of the landing server: " landing_port
    [ -z "${landing_port}" ]
    echo ""
    
    while true; do
        read -p "Please enter the local port for relay/listening (choose any port that is not in use): " local_port
        if lsof -Pi :$local_port -sTCP:LISTEN -t >/dev/null ; then
            echo "Port $local_port is already in use. Please choose a different port."
        else
            break
        fi
    done
    echo ""
    
    read -p "Please enter the forwarding protocol (raw/ws/wss/mwss): " transport_type
    case $transport_type in
        raw|ws|wss|mwss)
            ;;
        *)
            echo "Invalid forwarding protocol. Please enter one of the following: raw, ws, wss, mwss."
            exit 1
            ;;
    esac
    
    if [ ! -f "/etc/ehco/ehco.json" ]; then
        wget https://cdn.jsdelivr.net/gh/missuo/Ehcoo/ehco.json -O /etc/ehco/ehco.json
    fi
    
    JSON='{"listen":"0.0.0.0:local_port","listen_type":"transport_type","transport_type":"transport_type","tcp_remotes":["transport_type://ip:landing_port"],"udp_remotes":["ip:landing_port"]}'
    JSON=${JSON/local_port/$local_port}
    JSON=${JSON/transport_type/$transport_type}
    JSON=${JSON/ip/$ip}
    temp=$(jq --argjson groupInfo "$JSON" '.relay_configs += [$groupInfo]' /etc/ehco/ehco.json)
    echo $temp > /etc/ehco/ehco.json
    
    if [ ! -f "/etc/systemd/system/ehco.service" ]; then
        wget https://cdn.jsdelivr.net/gh/missuo/Ehcoo/ehco-forward.service -O ehco.service
        mv ehco.service /etc/systemd/system/
    fi
    
    echo "Starting the Ehco tunnel on this server."
    systemctl daemon-reload
    systemctl start ehco.service
    systemctl enable ehco.service
    systemctl restart ehco.service
    
    echo ""
    clear
    echo "The startup was successful, and the service has been set to start at boot. The Ehco tunnel's connection port is ${local_port}, using ${transport_type} forwarding protocol!"
    echo "Do not move the ehco.json file from the /etc/ehco/ directory; doing so could cause serious errors!"
    echo "Have a nice day :)"
}

install(){
    if [ ! -f "/usr/bin/ehco" ]; then
        echo "Starting the installation of the Ehco tunnel..."
        # Use GitHub API to fetch the latest release version number
        LATEST_VERSION=$(curl -s https://api.github.com/repos/Ehco1996/ehco/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)
        if [ -z "$LATEST_VERSION" ]; then
            echo "Failed to fetch the latest Ehco release version. Please check your internet connection or GitHub's status."
            exit 1
        fi
        # Construct the download URL using the latest version number
        DOWNLOAD_URL="https://github.com/Ehco1996/ehco/releases/download/${LATEST_VERSION}/ehco_${LATEST_VERSION:1}_linux_amd64"
        # Download the latest release
        curl -L $DOWNLOAD_URL -o ehco
        chmod +x ehco
        mv ehco /usr/bin
    fi
    echo "Congratulations, Ehco has been successfully installed. Now starting to configure and launch the Ehco service."
    echo ""
}

start_menu(){
    clear
    echo && echo -e "Ehco Easy Script Made by missuo
Update content and feedback: https://github.com/missuo/EasyEhco
————————————Mode Selection————————————
${green}1.${plain} Configure landing server
${green}2.${plain} Configure relay server
${green}3.${plain} Permanently disable
${green}4.${plain} Re-enable
${green}5.${plain} Restart tunnel
${green}0.${plain} Exit script
————————————————————————————————"
    read -p "Please enter a number: " num
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
        echo -e "[${red}Error${plain}]: Please enter the correct number [0-5]"
        sleep 5s
        start_menu
        ;;
    esac
}
start_menu

