# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0
#

deployment "simple" {
  inputs = {
    prefix           = "simple"
    instances        = 0
  }
}

deployment "complex" {
  inputs = {
    prefix           = "complex"
    instances        = 3
  }
}
