## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

resource "oci_core_volume" "gluster_blockvolume" {
  count = var.gluster_server_node_count * var.gluster_server_disk_count
  availability_domain = var.availability_domain_name == "" ? data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain_number]["name"] : var.availability_domain_name
  compartment_id      = var.compartment_ocid
  display_name        = "server${count.index % var.gluster_server_node_count + 1}-brick${count.index % var.gluster_server_disk_count + 1}"
  size_in_gbs         = var.gluster_server_disk_size
  vpus_per_gb         = var.gluster_server_disk_vpus_per_gb
  defined_tags = {"${oci_identity_tag_namespace.ArchitectureCenterTagNamespace.name}.${oci_identity_tag.ArchitectureCenterTag.name}" = var.release }
}

resource "oci_core_volume_attachment" "blockvolume_attach" {
  attachment_type = "iscsi"
  count = var.gluster_server_node_count * var.gluster_server_disk_count
  instance_id = element(
    oci_core_instance.gluster_server.*.id,
    count.index % var.gluster_server_node_count,
  )
  volume_id = element(oci_core_volume.gluster_blockvolume.*.id, count.index)

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host = element(
        oci_core_instance.gluster_server.*.private_ip,
        count.index % var.gluster_server_node_count,
      )
      user                = var.ssh_user
      private_key         = tls_private_key.public_private_key_pair.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.public_private_key_pair.private_key_pem
    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}


/*
  Notify server nodes that all block-attach is complete, so  server nodes can continue with their rest of the instance setup logic in cloud-init.
*/
resource "null_resource" "notify_server_nodes_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.blockvolume_attach ]
  count = var.gluster_server_node_count
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.gluster_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.public_private_key_pair.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.public_private_key_pair.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/block-attach.complete",
    ]
  }
}
