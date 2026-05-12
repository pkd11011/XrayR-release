#!/bin/bash

# ==========================================
# THÔNG TIN REPO CỦA BẠN
# ==========================================
MY_USER="pkd11011"
MY_REPO="XrayR-release"
# ==========================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/${MY_USER}/${MY_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 XrayR 版本失败，请确认 https://github.com/${MY_USER}/${MY_REPO}/releases 已经发布版本${plain}"
            exit 1
        fi
        echo -e "检测到 XrayR 最新版本：${last_version}，开始安装"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/${MY_USER}/${MY_REPO}/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 XrayR 失败，请确认 Asset XrayR-linux-${arch}.zip 存在${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	    else
	        last_version="v"$1
	    fi
        url="https://github.com/${MY_USER}/${MY_REPO}/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "开始安装 XrayR ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 XrayR ${last_version} 失败，请确认 ${url} 存在${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    systemctl unmask XrayR 2>/dev/null
    rm /etc/systemd/system/XrayR.service -f
    
    # Tải file service từ repo của pkd11011
    file_service="https://raw.githubusercontent.com/${MY_USER}/${MY_REPO}/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file_service}
    
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} 安装完成，已设置开机自启"
    
    # Copy các file database mẫu nếu có
    [[ -f geoip.dat ]] && cp geoip.dat /etc/XrayR/
    [[ -f geosite.dat ]] && cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/${MY_USER}/${MY_REPO}，配置必要的内容"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 重启成功${plain}"
        else
            echo -e "${red}XrayR 可能启动失败，请稍后使用 XrayR log 查看日志信息${plain}"
        fi
    fi

    # Copy các file json cấu hình nếu có
    [[ -f dns.json ]] && cp dns.json /etc/XrayR/
    [[ -f route.json ]] && cp route.json /etc/XrayR/
    [[ -f custom_outbound.json ]] && cp custom_outbound.json /etc/XrayR/
    [[ -f custom_inbound.json ]] && cp custom_inbound.json /etc/XrayR/
    [[ -f rulelist ]] && cp rulelist /etc/XrayR/

    # Tải script quản lý XrayR.sh từ repo của pkd11011
    curl -fLo /usr/bin/XrayR https://raw.githubusercontent.com/${MY_USER}/${MY_REPO}/master/XrayR.sh
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 XrayR 管理脚本失败，请检查 raw link${plain}"
        exit 1
    fi
    
    chmod +x /usr/bin/XrayR
    ln -sf /usr/bin/XrayR /usr/bin/xrayr 
    chmod +x /usr/bin/xrayr
    
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "XrayR 管理脚本 sử dụng phương pháp: "
    echo "------------------------------------------"
    echo "XrayR                    - Menu quản lý"
    echo "XrayR log                - Xem nhật ký"
    echo "XrayR update             - Cập nhật"
    echo "XrayR restart            - Khởi động lại"
    echo "------------------------------------------"
}

echo -e "${green}开始安装 (Nguồn: ${MY_USER})${plain}"
install_base
install_XrayR $1
