## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

variable "marketplace_source_images" {
  type = map(object({
    ocid = string
    is_pricing_associated = bool
    compatible_shapes = set(string)
  }))
  default = {
    main_mktpl_image = {
      ocid = "ocid1.image.oc1..aaaaaaaaqgspr7vy2xs2xdyqqvxyrdgizkxnbmq5pqwxr4rmnnbnl6cays2a"
      is_pricing_associated = false
      compatible_shapes = []
    }
  }
}
