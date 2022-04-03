#!/bin/bash

:<<"USAGE"
$0 Filename captiveportal.sh
$1 SSID when connecting to external wifi
$2 SSIDPASSWORD when connecting to external wifi
USAGE

if [ "$EUID" -ne 0 ]
        then echo "Must be root, run sudo -i before running this script."
        exit
fi

echo "┌─────────────────────────────────────────"
echo "|This script might take a while,"
echo "|so if you dont see much progress,"
echo "|wait till you see --all done-- message."
echo "└─────────────────────────────────────────"
read -p "Press enter to continue"

echo "┌─────────────────────────────────────────"
echo "|Downloading config files"
echo "└─────────────────────────────────────────"
mkdir config_files
wget -q https://raw.githubusercontent.com/tretos53/Captive-Portal-wpa/master/default_nginx -O config_files/default_nginx
wget -q https://raw.githubusercontent.com/tretos53/Captive-Portal-wpa/master/index.php -O config_files/index.php
wget -q https://raw.githubusercontent.com/tretos53/Captive-Portal-wpa/master/dnsmasq.conf -O config_files/dnsmasq.conf
wget -q https://raw.githubusercontent.com/tretos53/Captive-Portal-wpa/master/resolved.conf -O config_files/resolved.conf
wget -q https://raw.githubusercontent.com/tretos53/Captive-Portal-wpa/master/ap.sh -O ap.sh
wget -q https://raw.githubusercontent.com/tretos53/Captive-Portal-wpa/master/wlan.sh -O wlan.sh

echo "┌─────────────────────────────────────────"
echo "|Updating repositories"
echo "└─────────────────────────────────────────"
apt-get update -yqq

echo "┌─────────────────────────────────────────"
echo "|Installing iptables-persistent and iptables"
echo "└─────────────────────────────────────────"
apt-get install iptables -yqq
apt-get install iptables-persistent -yqq

echo "┌─────────────────────────────────────────"
echo "|Installing and configuring nginx"
echo "└─────────────────────────────────────────"
apt-get install nginx -yqq
cp config_files/default_nginx /etc/nginx/sites-enabled/default
cp config_files/index.php /var/www/html/index.php

echo "┌─────────────────────────────────────────"
echo "|Installing PHP7"
echo "└─────────────────────────────────────────"
apt-get install php7.4-fpm php7.4-mbstring php7.4-mysql php7.4-curl php7.4-gd php7.4-curl php7.4-zip php7.4-xml -yqq > /dev/null
systemctl restart nginx.service 

echo "┌─────────────────────────────────────────"
echo "|Installing and configuring dnsmasq"
echo "└─────────────────────────────────────────"
apt-get install dnsmasq -yqq
cp config_files/dnsmasq.conf /etc/dnsmasq.conf

echo "┌─────────────────────────────────────────"
echo "|disable debian networking and dhcpcd"
echo "└─────────────────────────────────────────"
systemctl mask networking.service
systemctl mask dhcpcd.service
mv /etc/network/interfaces /etc/network/interfaces~
sed -i '1i resolvconf=NO' /etc/resolvconf.conf

echo "┌─────────────────────────────────────────"
echo "|enable systemd-networkd"
echo "└─────────────────────────────────────────"
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
cp config_files/resolved.conf /etc/systemd/resolved.conf
systemctl restart systemd-resolved.service
systemctl restart dnsmasq.service

echo "┌─────────────────────────────────────────"
echo "|Creating wlan0 wpa_supplicant file"
echo "└─────────────────────────────────────────"
cat >/etc/wpa_supplicant/wpa_supplicant-wlan0.conf <<EOF
country=GB
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$1"
    psk="$2"
}
EOF

chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
systemctl disable wpa_supplicant.service
systemctl enable wpa_supplicant@wlan0.service

echo "┌─────────────────────────────────────────"
echo "|Creating ap0 wpa_supplicant file"
echo "└─────────────────────────────────────────"
cat >/etc/wpa_supplicant/wpa_supplicant-ap0.conf <<EOF
country=GB
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="CaptivePortalWPA"
    mode=2
    key_mgmt=NONE
    frequency=2412
}
EOF

chmod 600 /etc/wpa_supplicant/wpa_supplicant-ap0.conf

echo "┌─────────────────────────────────────────"
echo "|Creating both wlan0 and ap0 systemd network files"
echo "└─────────────────────────────────────────"

cat >/etc/systemd/network/08-wlan0.network <<EOF
[Match]
Name=wlan0
[Network]
DHCP=yes
EOF

cat >/etc/systemd/network/12-ap0.network <<EOF
[Match]
Name=ap0
[Network]
Address=192.168.24.1/24
DHCPServer=yes
[DHCPServer]
DNS=192.168.24.1
EOF

echo "┌─────────────────────────────────────────"
echo "|Editing Systemd"
echo "└─────────────────────────────────────────"
systemctl disable wpa_supplicant@ap0.service
cp /lib/systemd/system/wpa_supplicant@.service /etc/systemd/system/wpa_supplicant@ap0.service
sed -i 's/Requires=sys-subsystem-net-devices-%i.device/Requires=sys-subsystem-net-devices-wlan0.device/' /etc/systemd/system/wpa_supplicant@ap0.service
sed -i 's/After=sys-subsystem-net-devices-%i.device/After=sys-subsystem-net-devices-wlan0.device/' /etc/systemd/system/wpa_supplicant@ap0.service
sed -i '/After=sys-subsystem-net-devices-wlan0.device/a Conflicts=wpa_supplicant@wlan0.service' /etc/systemd/system/wpa_supplicant@ap0.service
sed -i '/Type=simple/a ExecStartPre=/sbin/iw dev wlan0 interface add ap0 type __ap' /etc/systemd/system/wpa_supplicant@ap0.service
sed -i '/ExecStart=/a ExecStopPost=/sbin/iw dev ap0 del' /etc/systemd/system/wpa_supplicant@ap0.service
systemctl daemon-reload

echo "┌─────────────────────────────────────────"
echo "|Configuring iptables"
echo "└───────────────────────────────────                      ──────"
iptables -t nat -A PREROUTING -s 192.168.24.0/24 -p tcp --dport 80 -j DNAT --to-destination 192.168.24.1:80
iptables -t nat -A POSTROUTING -j MASQUERADE
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
netfilter-persistent save

echo "┌─────────────────────────────────────────"
echo "|Enabling AP mode as default"
echo "└─────────────────────────────────────────"
sleep 5
systemctl stop wpa_supplicant@wlan0.service
systemctl disable wpa_supplicant@wlan0.service
systemctl enable wpa_supplicant@ap0.service
systemctl start wpa_supplicant@ap0.service

echo "┌─────────────────────────────────────────"
echo "|Please reboot your pi and test."
echo "|To switch between AP and External WIFI mode"
echo "|run ap.sh or wlan.sh respectively"
echo "└─────────────────────────────────────────"
