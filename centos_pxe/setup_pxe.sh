#!/bin/bash

echo Install PXE server

mkfs.xfs /dev/sdb
echo "/dev/sdb /var/www xfs defaults 0 0" >> /etc/fstab
mkdir /var/www
mount -a

yum -y install epel-release
yum -y install dhcp-server
yum -y install tftp-server
yum -y install httpd
firewall-cmd --add-service=tftp --permanent
firewall-cmd --add-service=http --permanent
# disable selinux or permissive
setenforce 0
# 

cat >/etc/dhcp/dhcpd.conf <<EOF
option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;
subnet 10.0.0.0 netmask 255.255.255.0 {
	#option routers 10.0.0.254;
	range 10.0.0.100 10.0.0.120;
	class "pxeclients" {
	  match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
	  next-server 10.0.0.20;
	  if option architecture-type = 00:07 {
	    filename "uefi/shim.efi";
	    } else {
	    filename "pxelinux/pxelinux.0";
	  }
	}
}
EOF
systemctl enable --now dhcpd

systemctl enable --now tftp.service
yum -y install syslinux-tftpboot.noarch
mkdir /var/lib/tftpboot/pxelinux
cp /tftpboot/pxelinux.0 /var/lib/tftpboot/pxelinux
cp /tftpboot/libutil.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/menu.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/libmenu.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/ldlinux.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/vesamenu.c32 /var/lib/tftpboot/pxelinux
cp /tftpboot/chain.c32 /var/lib/tftpboot/pxelinux/
cp /tftpboot/libcom32.c32 /var/lib/tftpboot/pxelinux/

mkdir /var/lib/tftpboot/pxelinux/pxelinux.cfg

cat >/var/lib/tftpboot/pxelinux/pxelinux.cfg/default <<EOF
default menu
prompt 0
timeout 600
MENU TITLE Demo PXE setup
LABEL linux
  menu label ^Install system
  menu default
  kernel images/CentOS-8.3/vmlinuz
  append initrd=images/CentOS-8.3/initrd.img ip=enp0s3:dhcp inst.repo=http://10.0.0.20/centos8-install
LABEL linux-auto
  menu label ^Auto install system
  kernel images/CentOS-8.3/vmlinuz
  append initrd=images/CentOS-8.3/initrd.img ip=enp0s3:dhcp inst.ks=http://10.0.0.20/ks.cfg inst.repo=http://10.0.0.20/centos8-install
LABEL local
  menu label Boot from ^local drive
  kernel chain.c32
  append hd0 0
EOF

centos_version="8.3.2011"

mkdir -p /var/lib/tftpboot/pxelinux/images/CentOS-8.3/
curl -O http://ftp.mgts.by/pub/CentOS/${centos_version}/BaseOS/x86_64/os/images/pxeboot/initrd.img
curl -O http://ftp.mgts.by/pub/CentOS/${centos_version}/BaseOS/x86_64/os/images/pxeboot/vmlinuz
cp {vmlinuz,initrd.img} /var/lib/tftpboot/pxelinux/images/CentOS-8.3/


# Setup NFS auto install
# 
cd /var/www
curl -O http://ftp.mgts.by/pub/CentOS/${centos_version}/isos/x86_64/CentOS-${centos_version}-x86_64-dvd1.iso
mkdir /var/www/html/centos8-install
mount -t iso9660 CentOS-${centos_version}-x86_64-dvd1.iso /var/www/html/centos8-install
systemctl enable --now httpd


cat > /var/www/html/ks.cfg <<EOF
#version=RHEL8
ignoredisk --only-use=sda
autopart --type=lvm
authconfig --enableshadow --passalgo=sha512
# Partition clearing information
clearpart --all --initlabel --drives=sda
# Use graphical install
graphical
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8
#repo
#url --url=http://ftp.mgts.by/pub/CentOS/8.3.2011/BaseOS/x86_64/os/
# Network information
network  --bootproto=dhcp --device=enp0s3 --ipv6=auto --activate
network  --bootproto=dhcp --device=enp0s8 --onboot=off --ipv6=auto --activate
network  --hostname=localhost.localdomain
# Root password
rootpw --iscrypted \$6\$8Ee5V7vP2GiCPlAM\$B4pb4wzsY3jGDk3Ml8/QtE99wseC9LK7UqVgpvgXxFLxqpwuXzh8zDQuo0QYtX3bKM9cbu5TPcewMsyrTP58j1
# Run the Setup Agent on first boot
firstboot --enable
# Do not configure the X Window System
skipx
# System services
services --enabled="chronyd"
# System timezone
timezone America/New_York --isUtc
user --groups=wheel --name=val --password=\$6\$8Ee5V7vP2GiCPlAM\$B4pb4wzsY3jGDk3Ml8/QtE99wseC9LK7UqVgpvgXxFLxqpwuXzh8zDQuo0QYtX3bKM9cbu5TPcewMsyrTP58j1 --iscrypted --gecos="val"
%packages
@^minimal-environment
kexec-tools
%end
%addon com_redhat_kdump --enable --reserve-mb='auto'
%end
%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
EOF
systemctl reload httpd.service
