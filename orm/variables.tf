## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

#variable "user_ocid" {}
#variable "fingerprint" {}
#variable "private_key_path" {}

variable "availability_domain_name" {
  default = ""
}
variable "availability_domain_number" {
  default = 0
}

variable "release" {
  description = "Reference Architecture Release (OCI Architecture Center)"
  default     = "1.0.2"
}

variable "vcn_cidr" { default = "10.0.0.0/16" }

variable "bastion_shape" { default = "VM.Standard2.2" }
variable "bastion_node_count" { default = 1 }
variable "bastion_hostname_prefix" { default = "bastion-" }

#  BM.Standard2.52
variable "gluster_server_shape" { default = "BM.Standard2.52" }
variable "gluster_server_node_count" { default = 3 }
variable "gluster_server_disk_count" { default = 8 }
# 800
variable "gluster_server_disk_size" { default = 800 }
# Make sure disk_count is a multiplier of num_of_disks_in_brick.  i.e: disk_count/num_of_disks_in_brick = an Integer, eg: disk_count=8,num_of_disks_in_brick=4 (8/4=2).
variable "gluster_server_num_of_disks_in_brick" { default = 1 }
# Block volume elastic performance tier.  The number of volume performance units (VPUs) that will be applied to this volume per GB, representing the Block Volume service's elastic performance options. See https://docs.cloud.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeelasticperformance.htm for more information.  Allowed values are 0, 10, and 20.  Recommended value is 10 for balanced performance and 20 to receive higher performance (IO throughput and IOPS) per GB.
variable "gluster_server_disk_vpus_per_gb" { default = "20" }
variable "gluster_server_hostname_prefix" { default = "g-server-" }



# Client nodes variables
variable "client_node_shape" { default = "VM.Standard2.24" }
variable "client_node_count" { default = 1 }
variable "client_node_hostname_prefix" { default = "g-compute-" }


/*
  Gluster FS related variables
*/
# Valid values "5.9" , "3.12" on Oracle Linux Operating System
variable "gluster_version" { default = "5.9" }
# valid values are Distributed, Dispersed , DistributedDispersed, DistributedReplicated, Replicated
variable "gluster_volume_types" { default = "Distributed" }
# replica field used only when VolumeTypes is "Replicated" or "DistributedReplicated". Otherwise assume no replication of data (replica=1 means no replication, only 1 copy of data in filesystem.)
variable "gluster_replica" { default = 1 }
# Has to be in Kilobytes only. Mention only numerical value, example 256, not 256K
variable "gluster_block_size" { default = "128" }
variable "gluster_mount_point" { default = "/glusterfs" }
# To be supported in future
variable "gluster_high_availability" { default = false }


##################################################
## Variables which should not be changed by user
##################################################

variable "scripts_directory" { default = "scripts" }

variable "gluster_ol_repo_mapping" {
  type = map(string)
  default = {
    "5.9"  = "http://yum.oracle.com/repo/OracleLinux/OL7/gluster5/x86_64"
    "3.12" = "http://yum.oracle.com/repo/OracleLinux/OL7/gluster312/x86_64"
  }
}

variable "volume_attach_device_mapping" {
  type = map(string)
  default = {
    "0"  = "/dev/oracleoci/oraclevdb"
    "1"  = "/dev/oracleoci/oraclevdc"
    "2"  = "/dev/oracleoci/oraclevdd"
    "3"  = "/dev/oracleoci/oraclevde"
    "4"  = "/dev/oracleoci/oraclevdf"
    "5"  = "/dev/oracleoci/oraclevdg"
    "6"  = "/dev/oracleoci/oraclevdh"
    "7"  = "/dev/oracleoci/oraclevdi"
    "8"  = "/dev/oracleoci/oraclevdj"
    "9"  = "/dev/oracleoci/oraclevdk"
    "10" = "/dev/oracleoci/oraclevdl"
    "11" = "/dev/oracleoci/oraclevdm"
    "12" = "/dev/oracleoci/oraclevdn"
    "13" = "/dev/oracleoci/oraclevdo"
    "14" = "/dev/oracleoci/oraclevdp"
    "15" = "/dev/oracleoci/oraclevdq"
    "16" = "/dev/oracleoci/oraclevdr"
    "17" = "/dev/oracleoci/oraclevds"
    "18" = "/dev/oracleoci/oraclevdt"
    "19" = "/dev/oracleoci/oraclevdu"
    "20" = "/dev/oracleoci/oraclevdv"
    "21" = "/dev/oracleoci/oraclevdw"
    "22" = "/dev/oracleoci/oraclevdx"
    "23" = "/dev/oracleoci/oraclevdy"
    "24" = "/dev/oracleoci/oraclevdz"
    "25" = "/dev/oracleoci/oraclevdaa"
    "26" = "/dev/oracleoci/oraclevdab"
    "27" = "/dev/oracleoci/oraclevdac"
    "28" = "/dev/oracleoci/oraclevdad"
    "29" = "/dev/oracleoci/oraclevdae"
    "30" = "/dev/oracleoci/oraclevdaf"
    "31" = "/dev/oracleoci/oraclevdag"
  }
}


###############

variable "region" {}
variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "availablity_domain_name" {}


/*
  For instances created using Oracle Linux and CentOS images, the user name opc is created automatically.
  For instances created using the Ubuntu image, the user name ubuntu is created automatically.
  The ubuntu user has sudo privileges and is configured for remote access over the SSH v2 protocol using RSA keys. The SSH public keys that you specify while creating instances are added to the /home/ubuntu/.ssh/authorized_keys file.
  For more details: https://docs.cloud.oracle.com/iaas/Content/Compute/References/images.htm#one
  For Ubuntu images,  set to ubuntu.
  # variable "ssh_user" { default = "ubuntu" }
*/
variable "ssh_user" { default = "opc" }


locals {
  server_dual_nics                       = (length(regexall("^BM", var.gluster_server_shape)) > 0 ? true : false)
  storage_subnet_domain_name             = ("${data.oci_core_subnet.storage_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com")
  filesystem_subnet_domain_name          = ("${data.oci_core_subnet.fs_subnet.dns_label}.${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com")
  vcn_domain_name                        = ("${data.oci_core_vcn.vcn.dns_label}.oraclevcn.com")
  server_filesystem_vnic_hostname_prefix = "${var.gluster_server_hostname_prefix}fs-vnic-"

  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
}


# This is currently used for the deployment. Valid values 0,1,2.
variable "ad_number" {
  default = "-1"
}

#-------------------------------------------------------------------------------------------------------------
# Marketplace variables
# ------------------------------------------------------------------------------------------------------------
# Oracle Linux 7.7 UEK Image for GlusterFS filesystem

variable "mp_listing_id" {
  default = "ocid1.appcataloglisting.oc1..aaaaaaaa6fjcgyilbaa3zegmdvwsaztjq6gaijhnognzmipz2l6lhnx3ykza"
}
variable "mp_listing_resource_id" {
  default = "ocid1.image.oc1..aaaaaaaaqgspr7vy2xs2xdyqqvxyrdgizkxnbmq5pqwxr4rmnnbnl6cays2a"
}
variable "mp_listing_resource_version" {
  default = "1.0"
}

variable "use_marketplace_image" {
  default = false
}


variable "use_existing_vcn" {
  default = "false"
}

variable "vcn_id" {
  default = ""
}

variable "bastion_subnet_id" {
  default = ""
}

variable "storage_subnet_id" {
  default = ""
}

variable "fs_subnet_id" {
  default = ""
}

locals {
  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
  storage_subnet_id = var.use_existing_vcn ? var.storage_subnet_id : element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  fs_subnet_id      = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
  client_subnet_id  = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)

}

# OS Images  CentOS 7.x
variable "instance_os" {
  description = "Operating system for compute instances"
  default     = "CentOS"
}

variable "linux_os_version" {
  description = "Operating system version for all Linux instances"
  default     = "7"
}
