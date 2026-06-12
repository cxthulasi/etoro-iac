terraform {
  # >= 1.10 required for S3 native state locking (backend use_lockfile=true).
  required_version = ">= 1.10"

  required_providers {
    coralogix = {
      source  = "coralogix/coralogix"
      version = "~> 3.1"
    }
  }

  # Partial backend configuration. Concrete values (bucket, key, region,
  # use_lockfile) are supplied at init time via -backend-config flags,
  # either by the CI buildspec or by a local `terraform init -migrate-state`.
  # State locking uses S3 native lockfiles (use_lockfile=true), which requires
  # Terraform >= 1.10. No DynamoDB table is needed.
  backend "s3" {}
}

provider "coralogix" {
  env = "AP1"
  # api_key via CORALOGIX_API_KEY env var
}
