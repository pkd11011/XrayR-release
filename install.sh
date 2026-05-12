#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# Kiểm tra quyền root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} Bạn phải sử dụng quyền root để chạy script này!\n" && exit 1

# Kiểm tra hệ điều hành
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
    echo -e "${red}Không phát hiện được phiên bản hệ thống, vui lòng liên hệ tác giả!${plain}\n" && exit 1
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
    echo -e "${red}Phát hiện kiến trúc thất bại, sử dụng kiến trúc mặc định: ${arch}${plain}"
fi

echo "Kiến trúc CPU: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64)."
    exit 2
fi

os_version=""

# Phiên bản hệ điều hành
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc phiên bản cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 hoặc phiên bản cao hơn!${plain}\n" && exit 1
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

# 0: đang chạy, 1: không chạy, 2: chưa cài đặt
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
        # Trỏ về repo pkd11011/Xrayr0.9.5
        last_version=$(curl -Ls "https://api.github.com/repos/pkd11011/Xrayr0.9.5/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Phát hiện phiên bản XrayR thất bại, vui lòng kiểm tra mục Release tại https://github.com/pkd11011/Xrayr0.9.5/releases${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản XrayR mới nhất: ${last_version}, bắt đầu cài đặt"
        # Tải từ pkd11011
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip https://github.com/pkd11011/Xrayr0.9.5/releases/download/${last_version}/XrayR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống XrayR thất bại, vui lòng đảm bảo file tồn tại trong Release của pkd11011.${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        # Tải từ pkd11011
        url="https://github.com/pkd11011/Xrayr0.9.5/releases/download/${last_version}/XrayR-linux-${arch}.zip"
        echo -e "Bắt đầu cài đặt XrayR ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống XrayR ${last_version} thất bại, vui lòng kiểm tra lại link tải.${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    systemctl unmask XrayR 2>/dev/null
    rm /etc/systemd/system/XrayR.service -f
    # Tải Service từ repo của bạn
    file="https://raw.githubusercontent.com/pkd11011/Xrayr0.9.5/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} đã cài đặt xong, đã thiết lập tự khởi động cùng hệ thống"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "Cài đặt mới hoàn tất, vui lòng tham khảo hướng dẫn tại: https://github.com/pkd11011/Xrayr0.9.5"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR đã khởi động lại thành công${plain}"
        else
            echo -e "${red}XrayR có thể đã khởi động thất bại, vui lòng dùng 'XrayR log' để kiểm tra nhật ký.${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
        cp rulelist /etc/XrayR/
    fi
    
    # Tải Script quản lý Menu từ repo của bạn
    curl -fLo /usr/bin/XrayR https://raw.githubusercontent.com/pkd11011/Xrayr0.9.5/master/XrayR.sh
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Tải xuống script quản lý thất bại, vui lòng kiểm tra lại link raw.${plain}"
        exit 1
    fi
    chmod +x /usr/bin/XrayR
    ln -sf /usr/bin/XrayR /usr/bin/xrayr # Tương thích chữ thường
    chmod +x /usr/bin/xrayr
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Cách sử dụng script quản lý XrayR (Gõ XrayR hoặc xrayr): "
    echo "------------------------------------------"
    echo "XrayR                    - Hiển thị menu quản lý"
    echo "XrayR start              - Khởi động XrayR"
    echo "XrayR stop               - Dừng XrayR"
    echo "XrayR restart            - Khởi động lại XrayR"
    echo "XrayR status             - Kiểm tra trạng thái"
    echo "XrayR log                - Xem nhật ký hoạt động"
    echo "XrayR config             - Hiển thị nội dung cấu hình"
    echo "XrayR uninstall          - Gỡ cài đặt XrayR"
    echo "------------------------------------------"
}

echo -e "${green}Bắt đầu quá trình cài đặt (Nguồn: pkd11011)${plain}"
install_base
install_XrayR $1
