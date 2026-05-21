terraform {
  required_version = ">= 1.9"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.2"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state"
    key    = "authentik/terraform.tfstate"
    region = "garage"  # Garage ignores region but the field is required

    endpoints = {
      s3 = "http://garage.internal:3900"
    }

    # Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
