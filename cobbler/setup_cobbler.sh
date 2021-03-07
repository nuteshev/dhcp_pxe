#!/bin/bash

# workaround with DNS server
echo 'nameserver 8.8.8.8 > /etc/resolv.conf'
echo Install cobbler
yum -y install epel-release
yum -y install cobbler

cp /vagrant/settings /etc/cobbler/


systemctl enable --now httpd 

# cobbler utilities 
yum -y install yum-utils  pykickstart debmirror
cobbler get-loaders
# for managed dhcp server
yum -y install dhcp bind fence-agents tftp-server tftp
# web interface
yum -y install cobbler-web

#  enable and start rsyncd.service with systemctl
systemctl enable --now rsyncd.service


# sed 's/next_server: 127.0.0.1/next_server: 192.168.1.10/' /etc/cobbler/settings
# sed 's/^server: 127.0.0.1/server: 192.168.1.10/' /etc/cobbler/settings
# sed 's/^manage_dhcp: 0/manage_dhcp: 1/' /etc/cobbler/settings
sed -i '/disable/ s/yes/no/' /etc/xinetd.d/tftp
sed -i 's/^@dists/# @dists/' /etc/debmirror.conf
sed -i 's/^@arches/# @arches/' /etc/debmirror.conf
sed -i '/version_file/ s/centos/centos|centos-linux|centos-stream/' /var/lib/cobbler/distro_signatures.json
sed -i 's/192\.168\.1/192.168.2/g' /etc/cobbler/dhcp.template



systemctl enable --now cobblerd
cobbler check
cobbler get-loaders



cd ~
centos_version="8.3.2011"
curl -O http://ftp.mgts.by/pub/CentOS/${centos_version}/isos/x86_64/CentOS-${centos_version}-x86_64-dvd1.iso
mkdir centos8-install
mount -t iso9660 CentOS-${centos_version}-x86_64-dvd1.iso ./centos8-install
cobbler import --name=rhel8 --arch=x86_64 --path=./centos8-install 
cobbler system add --name=pxeclient --profile=rhel8-x86_64
cobbler system edit --name=pxeclient --interface=eth0 --mac=00:11:22:AA:BB:CC --ip-address=192.168.2.100 --netmask=255.255.255.0 --static=1
cobbler system edit --name=pxeclient --gateway=192.168.2.1
cobbler sync

systemctl enable --now tftp.socket
