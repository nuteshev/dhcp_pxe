# disable selinux or permissive
sed -i '/^SELINUX=/ s/enforcing/disabled/' /etc/selinux/config