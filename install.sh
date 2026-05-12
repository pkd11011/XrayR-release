#!/bin/bash

# ==========================================
# THÔNG TIN REPO CỦA BẠN (ĐÃ FIX THEO LINK)
# ==========================================
MY_USER="pkd11011"
MY_REPO="Xrayr0.9.5"
MY_TAG="v0.9.5"
# ==========================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi:${plain} Bạn phải dùng quyền root để chạy script này!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
else
    release="ubuntu" # Mặc định nếu không nhận diện được
fi

# Tự động nhận diện kiến trúc CPU
arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
else
    arch="64"
    echo -e "${yellow}Không xác định được kiến trúc, mặc định dùng x64${plain}"
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

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
    cd /usr/local/XrayR/

    echo -e "${green}Đang tải XrayR ${MY_TAG} từ nguồn: ${MY_USER}/${MY_REPO}...${plain}"
    
    # Link tải file zip từ Release của bạn
    url="https://github.com/${MY_USER}/${MY_REPO}/releases/download/${MY_TAG}/XrayR-linux-${arch}.zip"
    
    wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Tải file XrayR thất bại! Hãy chắc chắn file XrayR-linux-${arch}.zip tồn tại trong Release ${MY_TAG}.${plain}"
        exit 1
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    
    # Tải file service từ repo của pkd11011
    rm /etc/systemd/system/XrayR.service -f
    file_service="https://raw.githubusercontent.com/${MY_USER}/${MY_REPO}/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file_service}
    
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    
    # Copy các file cần thiết
    [[ -f geoip.dat ]] && cp geoip.dat /etc/XrayR/
    [[ -f geosite.dat ]] && cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
    fi

    # Tải script quản lý XrayR.sh (Menu) từ repo của pkd11011
    curl -fLo /usr/bin/XrayR https://raw.githubusercontent.com/${MY_USER}/${MY_REPO}/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -sf /usr/bin/XrayR /usr/bin/xrayr 
    
    systemctl start XrayR
    
    echo -e "${green}XrayR ${MY_TAG}${plain} đã cài đặt thành công!"
    echo -e "------------------------------------------"
    echo -e "Gõ ${yellow}XrayR${plain} để mở menu quản lý"
    echo -e "File cấu hình: /etc/XrayR/config.yml"
    echo -e "------------------------------------------"
}

install_base
install_XrayR $1
