## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_core_vnic_attachment" "server_secondary_vnic_attachment" {
  count = var.gluster_server_node_count

  #Required
  create_vnic_details {
    #Required
    subnet_id = local.fs_subnet_id
# oci_core_subnet.fs[0].id

    #Optional
    assign_public_ip = "false"
    display_name     = "${local.server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"
    hostname_label   = "${local.server_filesystem_vnic_hostname_prefix}${format("%01d", count.index + 1)}"

    # false is default value
    skip_source_dest_check = "false"
  }
  instance_id = element(oci_core_instance.gluster_server.*.id, count.index)

  #Optional
  #display_name = "SecondaryVNIC"
  # set to 1, if you want to use 2nd physical NIC for this VNIC
  nic_index = (local.server_dual_nics ? "1" : "0")
}
