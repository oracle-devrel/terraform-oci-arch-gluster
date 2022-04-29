
set -x


echo "server_node_count = $server_node_count"
echo "server_hostname_prefix = $server_hostname_prefix"

# block_size is expected be to numerical only, but still check and remove k,K,kb,KB them, if they exist. 
lvm_stripe_size=`echo $block_size | gawk -F"k|K|KB|kb" ' { print $1 }'` ;
echo $lvm_stripe_size;

# list_length(): Return the length of the list
function list_length() {
  echo $(wc -w <<< "$@")
}


function update_resolvconf {
    #################   Update resolv.conf  ###############"
    ## Modify resolv.conf to ensure DNS lookups work from one private subnet to another subnet
    cp /etc/resolv.conf /etc/resolv.conf.backup
    rm -f /etc/resolv.conf
    echo "search ${storage_subnet_domain_name} ${filesystem_subnet_domain_name} ${vcn_domain_name} " > /etc/resolv.conf
    echo "nameserver 169.254.169.254" >> /etc/resolv.conf
}

# tuned_config(): Enable/Start Tuned
function tuned_config() {
  /sbin/chkconfig tuned on
  /sbin/service tuned start
  /sbin/tuned-adm profile throughput-performance

  /sbin/service irqbalance stop
  /sbin/chkconfig irqbalance off
}

function configure_nics() {
   # We use 2 VNICs - irrespective of BM/VM. One for storage traffic, another for server/client traffic

   # Wait till 2nd NIC is configured
   privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ;
   echo $privateIp | grep "\." ;
   while [ $? -ne 0 ];
   do
     sleep 10s
     echo "Waiting for 2nd Physical NIC to get configured with hostname"
     privateIp=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].privateIp ' | sed 's/"//g' ` ;
     echo $privateIp | grep "\." ;
   done
   vnicId=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].vnicId ' | sed 's/"//g' ` ;
   macAddr=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].macAddr ' | sed 's/"//g' ` ;
   subnetCidrBlock=`curl -s http://169.254.169.254/opc/v1/vnics/ | jq '.[1].subnetCidrBlock ' | sed 's/"//g' ` ;
   sleep 30s
   wget -O secondary_vnic_all_configure.sh https://docs.cloud.oracle.com/en-us/iaas/Content/Resources/Assets/secondary_vnic_all_configure.sh
   chmod +x secondary_vnic_all_configure.sh
   ./secondary_vnic_all_configure.sh -c
   sleep 30s
# Sometimes, "ip addr" , it returned empty. hence added another command.
   interface=`ip addr | grep -B2 $privateIp | grep "BROADCAST" | gawk -F ":" ' { print $2 } ' | sed -e 's/^[ \t]*//'`
   interface=`./secondary_vnic_all_configure.sh  | grep $vnicId |  gawk -F " " ' { print $8 } ' | sed -e 's/^[ \t]*//'`

   echo "$subnetCidrBlock via $privateIp dev $interface" >  /etc/sysconfig/network-scripts/route-$interface
   echo "Permanently configure 2nd VNIC...$interface"
   echo "DEVICE=$interface
HWADDR=$macAddr
ONBOOT=yes
TYPE=Ethernet
USERCTL=no
IPADDR=$privateIp
NETMASK=255.255.255.0
MTU=9000
NM_CONTROLLED=no
" > /etc/sysconfig/network-scripts/ifcfg-$interface

    systemctl status network.service
    ifdown $interface
    ifup $interface

    SecondVNicFQDNHostname=`nslookup $privateIp | grep "name = " | gawk -F"=" '{ print $2 }' | sed  "s|^ ||g" | sed  "s|\.$||g"`
    THIS_FQDN=$SecondVNicFQDNHostname
    THIS_HOST=${THIS_FQDN%%.*}
    SecondVNICDomainName=${THIS_FQDN#*.*}
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


config_node()
{
    # Disable firewalld TODO: Add firewall settings to node in future rev.
    systemctl stop firewalld
    systemctl disable firewalld

    # Disable SELinux
    cp /etc/selinux/config /etc/selinux/config.backup
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0

    cat /etc/os-release | grep "^NAME=" | grep "CentOS"
    if [ $? -eq 0 ]; then
      yum install -y centos-release-gluster --nogpgcheck
      yum install glusterfs-server -y
      yum install -y samba git nvme-cli
    else
      # Enable latest Oracle Linux Gluster release
      yum-config-manager --add-repo $gluster_yum_release
      yum install -y glusterfs-server samba git nvme-cli
    fi
    touch /var/log/CONFIG_COMPLETE
}


make_filesystem()
{
    # Create Logical Volume for Gluster Brick
    lvcreate -l 100%VG --stripes $lvm_stripes_cnt --stripesize "${block_size}K" -n $brick_name $vg_gluster_name
    lvdisplay

    # Create XFS filesystem with Inodes set at 512 and Directory block size at 8192
    # and set the su and sw for optimal stripe performance
    # lvm_stripe_size is assumed to be in KB, hence multiply by 1024 to convert to bytes.
    # su must be a multiple of the sector size (4096)
    # sw must be equal to # of disk within RAID or LVM.
    su=$((block_size*1024)) ;  echo $su
    sw=$((lvm_stripes_cnt)) ; echo $sw
    mkfs.xfs -f -i size=512 -n size=8192 -d su=${su},sw=${sw} /dev/${vg_gluster_name}/${brick_name}
    mkdir -p /bricks/${brick_name}
    mount -t xfs -o noatime,inode64,nobarrier /dev/${vg_gluster_name}/${brick_name} /bricks/${brick_name}
    echo "/dev/${vg_gluster_name}/${brick_name}  /bricks/${brick_name}    xfs     noatime,inode64,nobarrier  1 2" >> /etc/fstab
    df -h

    # Create gluster brick
    mkdir -p /bricks/${brick_name}/brick
}

create_bricks()
{

  nvme_lst=$(ls /dev/ | grep nvme | grep n1 | sort)
  nvme_cnt=$(ls /dev/ | grep nvme | grep n1 | wc -l)

  if [ $nvme_cnt -gt 0 ]; then

  brick_counter=1
  count=1
  # Configure physical volumes and volume group
      for disk in $nvme_lst
      do
          dataalignment=$((block_size)); echo $dataalignment;
          pvcreate --dataalignment $dataalignment  /dev/$disk
          physicalextentsize="${block_size}K";  echo $physicalextentsize
          vgcreate  --physicalextentsize $physicalextentsize vg_gluster_${brick_counter} /dev/$disk
          vgextend vg_gluster_${brick_counter} /dev/$disk
          vgdisplay
          brick_name="brick${brick_counter}"
          lvm_disk_count=1
          vg_gluster_name="vg_gluster_${brick_counter}"
          lvm_stripes_cnt=1
          make_filesystem
          brick_counter=$((brick_counter+1))
          count=$((count+1))
      done
  fi

  # Wait for block-attach of the Block volumes to complete. Terraform then creates the below file on server nodes of cluster.
  while [ ! -f /tmp/block-attach.complete ]
    do
      sleep 60s
      echo "Waiting for block-attach via Terraform to  complete ..."
    done


  # Gather list of block devices for brick config
  blk_lst=$(lsblk -d --noheadings | grep -v sda | grep -v nvme | awk '{ print $1 }' | sort)
  blk_cnt=$(lsblk -d --noheadings | grep -v sda | grep -v nvme | wc -l)

  # to prevent overlapping with nvme brick names.
  start_index=10
  # reset the counters.
  disk_per_brick_counter=0
  brick_counter=1
  count=1

  if [ $blk_cnt -ge $num_of_disks_in_brick ]; then

    # Configure physical volumes and volume group
    for disk in $blk_lst
    do
        index=$((brick_counter+start_index))
        dataalignment=$((num_of_disks_in_brick*block_size)); echo $dataalignment;
        pvcreate --dataalignment $dataalignment  /dev/$disk
        physicalextentsize="${block_size}K";  echo $physicalextentsize
        vgcreate  --physicalextentsize $physicalextentsize vg_gluster_$index /dev/$disk
        vgextend vg_gluster_$index /dev/$disk

        if [ $disk_per_brick_counter -lt $num_of_disks_in_brick ]; then
            disk_per_brick_counter=$((disk_per_brick_counter+1))
        fi

        # Logic for last set of disks to call make_filesystem
        if [ $blk_cnt -eq $count -o $disk_per_brick_counter -eq $num_of_disks_in_brick ]; then
            vgdisplay
            brick_name="brick${index}"
            lvm_disk_count=$((num_of_disks_in_brick*1))
            vg_gluster_name="vg_gluster_${index}"
            lvm_stripes_cnt=$num_of_disks_in_brick
            make_filesystem
            brick_counter=$((brick_counter+1))
            disk_per_brick_counter=0
        fi

        count=$((count+1))
    done

  else
    echo "Not enough disks attached"
    exit 1;
  fi
}




gluster_probe_peers()
{
    if [ "$(hostname -s | tail -c 3)" = "-1" ]; then
        echo GLUSTER PROBING PEERS
        sleep 60
        host=`hostname -i`
        for i in `seq 2 $server_node_count`;
        do
            gluster peer probe ${server_filesystem_vnic_hostname_prefix}${i}.${filesystem_subnet_domain_name} --mode=script
        done
        sleep 20
        gluster peer status
    fi
}



create_gluster_volumes()
{
    if [ "$(hostname -s | tail -c 3)" = "-1" ]; then

        # Gather list of block devices for brick config
        brick_lst=$(ls /bricks | sort)
        brick_cnt=$(ls /bricks | sort | wc -l)
        count=1
        buffer=""
        for brick in $brick_lst
        do
            for i in `seq 1 $server_node_count`;
            do
                buffer="$buffer ${server_filesystem_vnic_hostname_prefix}${i}:/bricks/${brick}/brick "
            done

            count=$((count+1))
        done

        if [ "$volume_types" = "Distributed" ]; then
            command_parameters=" transport tcp $buffer  force --mode=script"
        elif [ "$volume_types" = "DistributedReplicated" -o  "$volume_types" = "Replicated" ]; then
            command_parameters=" replica $replica transport tcp $buffer  force --mode=script"
        elif [ "$volume_types" = "DistributedDispersed" -o  "$volume_types" = "Dispersed" ]; then
            command_parameters=" disperse $server_node_count redundancy 1 transport tcp $buffer  force --mode=script"
        else
            echo "Invalid volume type input, exiting...."
            exit 1;
        fi

    gluster volume create glustervol $command_parameters
    sleep 20
    gluster volume set glustervol ctime off
    gluster volume start glustervol force --mode=script
    sleep 20
    gluster volume status --mode=script
    gluster volume info --mode=script

    fi
}

update_resolvconf
config_node
### tuned_config
configure_nics
### tune_nics
### tune_sysctl
create_bricks

# Start gluster services
systemctl enable glusterd.service
systemctl start glusterd.service
gluster_probe_peers
create_gluster_volumes

# Tuning
### gluster volume set  glustervol performance.cache-size 15GB
### gluster volume set  glustervol nfs.disable on
### gluster volume set  glustervol performance.io-cache on
### gluster volume set  glustervol performance.io-thread-count 32

touch /tmp/complete

exit 0
