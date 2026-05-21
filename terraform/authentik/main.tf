# ─── 1Password ───────────────────────────────────────────────────────────────
# Provider reads OP_SERVICE_ACCOUNT_TOKEN from the environment automatically —
# same token used by the load-secrets-action in the workflow.
#
# For local runs: export OP_SERVICE_ACCOUNT_TOKEN=<your-service-account-token>

provider "onepassword" {}

data "onepassword_item" "authentik" {
  vault = "kubernetes"
  title = "authentik"
}

data "onepassword_item" "cloudflare_turnstile" {
  vault = "kubernetes"
  title = "cloudflare-turnstile"
}

locals {
  op_authentik = { for f in data.onepassword_item.authentik.fields : f.label => f.value }
  op_turnstile = { for f in data.onepassword_item.cloudflare_turnstile.fields : f.label => f.value }

  authentik_token      = local.op_authentik["AUTHENTIK_TOKEN"]
  turnstile_site_key   = local.op_turnstile["site-key"]
  turnstile_secret_key = local.op_turnstile["secret-key"]
}

# ─── Authentik ────────────────────────────────────────────────────────────────

provider "authentik" {
  url   = "https://auth.materia.wtf"
  token = local.authentik_token
}

# ─── Data Sources ─────────────────────────────────────────────────────────────

data "authentik_flow" "default_provider_authorization_implicit_consent" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

data "authentik_property_mapping_provider_scope" "openid" {
  name = "authentik managed scope - openid"
}
data "authentik_property_mapping_provider_scope" "email" {
  name = "authentik managed scope - email"
}
data "authentik_property_mapping_provider_scope" "profile" {
  name = "authentik managed scope - profile"
}
data "authentik_property_mapping_provider_scope" "offline_access" {
  name = "authentik managed scope - offline_access"
}
