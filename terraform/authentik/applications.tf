# ─── How to add a new OIDC app ───────────────────────────────────────────────
#
# 1. Create an authentik_provider_oauth2 resource with the app's redirect URI(s)
# 2. Create an authentik_application resource pointing at the provider
# 3. Run `terraform apply` and capture the client_secret output
# 4. Store client_id + client_secret in 1Password under the app's item
# 5. Add/update the ExternalSecret in the app's Kubernetes manifests to pull them
#
# For apps that have no native OIDC support, use authentik_provider_proxy
# (forward auth mode) — see the "HTTP Basic Auth" section at the bottom.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Reused scope set across OIDC providers
  oidc_scopes = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
}

# ─── Grafana ─────────────────────────────────────────────────────────────────

resource "authentik_provider_oauth2" "grafana" {
  name          = "grafana"
  client_id     = "grafana"
  client_type   = "confidential"
  redirect_uris = ["https://grafana.materia.wtf/login/generic_oauth"]

  signing_key = data.authentik_certificate_key_pair.generated.id

  authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow  = authentik_flow.invalidation.uuid

  property_mappings = local.oidc_scopes
}

resource "authentik_application" "grafana" {
  name              = "Grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana.id
  group             = authentik_group.admins.name

  meta_launch_url  = "https://grafana.materia.wtf"
  meta_description = "Metrics & dashboards"
  open_in_new_tab  = true
}

# Restrict access to the admins group
resource "authentik_policy_binding" "grafana_admins" {
  target = authentik_application.grafana.uuid
  group  = authentik_group.admins.id
  order  = 0
}

# ─── Grafana outputs ─────────────────────────────────────────────────────────
# After `terraform apply`, store these in 1Password under 'grafana':
#   GF_AUTH_GENERIC_OAUTH_CLIENT_ID     = grafana
#   GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = <output below>
# Then update the grafana ExternalSecret to pull GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET
# and uncomment the auth.generic_oauth block in grafana.yaml.

output "grafana_client_secret" {
  value     = authentik_provider_oauth2.grafana.client_secret
  sensitive = true
}

# ─── HTTP Basic Auth (forward auth proxy pattern) ────────────────────────────
#
# Use this for apps that cannot do OIDC natively. Authentik's embedded outpost
# sits in front and injects HTTP Basic Auth headers that the upstream app reads.
#
# Example: a service that only accepts HTTP Basic Auth
#
# resource "authentik_provider_proxy" "myapp_basic" {
#   name          = "myapp-basic-auth"
#   mode          = "forward_single"
#   external_host = "https://myapp.materia.wtf"
#
#   basic_auth_enabled              = true
#   basic_auth_username_attribute   = "username"
#   basic_auth_password_attribute   = "httpBasicPassword"  # custom user attribute
#
#   authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
#   invalidation_flow  = authentik_flow.invalidation.uuid
# }
#
# resource "authentik_application" "myapp_basic" {
#   name              = "My App"
#   slug              = "myapp"
#   protocol_provider = authentik_provider_proxy.myapp_basic.id
#   meta_launch_url   = "https://myapp.materia.wtf"
#   open_in_new_tab   = true
# }
#
# Then add a SecurityPolicy to your HTTPRoute pointing at:
#   ak-outpost-authentik-embedded-outpost (the ReferenceGrant already covers this)
