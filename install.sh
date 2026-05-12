#!/bin/bash

# ==========================================
# THÔNG TIN REPO CỦA BẠN (pkd11011)
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
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Không nhận diện được hệ điều hành!${plain}\n" && exit 1
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
    echo -e "${red}Phát hiện kiến trúc thất bại, dùng mặc định x64${plain}"
fi

echo "Kiến trúc CPU: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này chỉ hỗ trợ hệ điều hành 64-bit."
    exit 2
fi

os_version=""
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
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

    # Luôn cài bản v0.9.5 từ Repo của bạn
    last_version="${MY_TAG}"
    
    echo -e "Bắt đầu tải XrayR từ nguồn cá nhân: ${MY_USER}/${MY_REPO}"
    wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/${MY_USER}/${MY_REPO}/releases/download/${last_version}/XrayR-linux-${arch}.zip
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Tải file thất bại! Hãy chắc chắn bạn đã upload đủ 49 file Assets vào Release ${MY_TAG}.${plain}"
        exit 1
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    
    # Tải file service từ repo của bạn
    systemctl unmask XrayR 2>/dev/null
    rm /etc/systemd/system/XrayR.service -f
    file_service="https://raw.githubusercontent.com/${MY_USER}/${MY_REPO}/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file_service}
    
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    
    echo -e "${green}XrayR ${last_version}${plain} đã cài đặt thành công."
    
    # Copy các file database nếu có
    [[ -f geoip.dat ]] && cp geoip.dat /etc/XrayR/
    [[ -f geosite.dat ]] && cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
    fi

    # Tải script quản lý XrayR.sh từ repo của bạn
    curl -fLo /usr/bin/XrayR https://raw.githubusercontent.com/${MY_USER}/${MY_REPO}/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -sf /usr/bin/XrayR /usr/bin/xrayr 
    chmod +x /usr/bin/xrayr
    
    systemctl start XrayR
    
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Cài đặt hoàn tất! Gõ 'XrayR' để mở menu quản lý."
}

echo -e "${green}Bắt đầu cài đặt XrayR (Nguồn: ${MY_USER})${plain}"
install_base
install_XrayR
