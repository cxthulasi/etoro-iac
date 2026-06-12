terraform {
  required_version = ">= 1.6"

  required_providers {
    coralogix = {
      source  = "coralogix/coralogix"
      version = "~> 3.1"
    }
  }
}
