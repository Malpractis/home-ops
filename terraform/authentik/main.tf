# ─── Authentik ────────────────────────────────────────────────────────────────
# The provider reads AUTHENTIK_TOKEN and AUTHENTIK_URL from the environment
# automatically — no explicit token block needed.
# Secrets are injected via TF_VAR_* env vars by the GHA workflow (load-secrets-action).

provider "authentik" {
  url = "https://auth.materia.wtf"
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
