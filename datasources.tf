## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

# Get list of availability domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

# Gets a list of Availability Domains
data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = var.compartment_ocid
}

data "oci_identity_region_subscriptions" "home_region_subscriptions" {
  tenancy_id = var.tenancy_ocid

  filter {
    name   = "is_home_region"
    values = [true]
  }
}


# Get the latest Oracle Linux image
data "oci_core_images" "GlusterServerImageOCID" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.instance_os
  operating_system_version = var.linux_os_version
  shape                    = var.gluster_server_shape

  filter {
    name   = "display_name"
    values = ["^.*CentOS[^G]*$"]
    regex  = true
  }
}

data "oci_core_images" "GlusterClientImageOCID" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.instance_os
  operating_system_version = var.linux_os_version
  shape                    = var.client_node_shape

  filter {
    name   = "display_name"
    values = ["^.*CentOS[^G]*$"]
    regex  = true
  }
}

data "oci_core_images" "BastionImageOCID" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.instance_os
  operating_system_version = var.linux_os_version
  shape                    = var.bastion_shape

  filter {
    name   = "display_name"
    values = ["^.*CentOS[^G]*$"]
    regex  = true
  }
}


data "oci_core_vcn" "vcn" {
  vcn_id = var.use_existing_vcn ? var.vcn_id : oci_core_vcn.vcn[0].id
}

data "oci_core_subnet" "storage_subnet" {
  subnet_id = var.use_existing_vcn ? var.storage_subnet_id : local.storage_subnet_id
}

data "oci_core_subnet" "fs_subnet" {
  subnet_id = var.use_existing_vcn ? var.fs_subnet_id : local.fs_subnet_id
}
