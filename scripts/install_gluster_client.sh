
set -x


# tuned_config(): Enable/Start Tuned
function tuned_config() {
  /sbin/chkconfig tuned on
  /sbin/service tuned start
  /sbin/tuned-adm profile throughput-performance
}

function tune_nics() {
  nic_lst=$(ifconfig | grep " flags" | grep -v "^lo:" | gawk -F":" '{ print $1 }' | sort) ; echo $nic_lst
  for nic in $nic_lst
  do
    ethtool -G $nic rx 2047 tx 2047 rx-jumbo 8191
  done
}

function tune_sysctl() {

  echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
  echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
  echo "net.core.wmem_default=16777216" >> /etc/sysctl.conf
  echo "net.core.rmem_default=16777216" >> /etc/sysctl.conf
  echo "net.core.optmem_max=16777216" >> /etc/sysctl.conf
  echo "net.core.netdev_max_backlog=27000" >> /etc/sysctl.conf
  echo "kernel.sysrq=1" >> /etc/sysctl.conf
  echo "kernel.shmmax=18446744073692774399" >> /etc/sysctl.conf
  echo "net.core.somaxconn=8192" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_adv_win_scale=2" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_low_latency=1" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_rmem = 212992 87380 16777216" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_sack = 1" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_wmem = 212992 65536 16777216" >> /etc/sysctl.conf
  echo "vm.min_free_kbytes = 65536" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_no_metrics_save = 0" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control = cubic" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_timestamps = 0" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control = htcp" >> /etc/sysctl.conf

  /sbin/sysctl -p /etc/sysctl.conf
}


function mount_glusterfs() {
    echo "sleep - 100s"
    sleep 100s
    sudo mkdir -p ${mount_point}
    sudo mount -t glusterfs -o defaults,_netdev,direct-io-mode=disable ${server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}:/glustervol ${mount_point}
}




cat /etc/os-release | grep "^NAME=" | grep "CentOS"
if [ $? -eq 0 ]; then
  yum install glusterfs glusterfs-fuse attr -y --nogpgcheck
else
  # Enable latest Oracle Linux Gluster release
  yum-config-manager --add-repo $gluster_yum_release
  sudo yum install glusterfs glusterfs-fuse attr -y
fi

### tuned_config
### tune_nics
### tune_sysctl

mount_glusterfs
while [ $? -ne 0 ]; do
    mount_glusterfs
done

touch /tmp/mount.complete

echo "${server_filesystem_vnic_hostname_prefix}1.${filesystem_subnet_domain_name}:/glustervol ${mount_point} glusterfs defaults,_netdev,direct-io-mode=disable 0 0" >> /etc/fstab




