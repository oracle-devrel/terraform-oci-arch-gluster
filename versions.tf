## Copyright (c) 2022 Oracle and/or its affiliates.
## All rights reserved. The Universal Permissive License (UPL), Version 1.0 as shown at http://oss.oracle.com/licenses/upl

terraform {
  required_version = ">= 0.12.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
    }
  }
}