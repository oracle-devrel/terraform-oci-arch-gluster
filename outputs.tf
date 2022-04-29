## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

output "SSH-login" {
value = <<END

        Bastion: ssh -i ~/.ssh/id_rsa ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]}

        Server1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.gluster_server.*.private_ip[0]}

        Client1: ssh -i CHANGEME  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i CHANGEME -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${oci_core_instance.bastion.*.public_ip[0]} -W %h:%p %r" ${var.ssh_user}@${oci_core_instance.client_node.*.private_ip[0]}

END
}

output "generated_ssh_private_key" {
  value = tls_private_key.public_private_key_pair.private_key_pem
  sensitive = true
}



