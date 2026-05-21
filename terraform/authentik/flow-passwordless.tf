# Passwordless / passkey-only login. The user enters their email, then
# authenticates with a registered WebAuthn passkey — no password involved.
# This flow is linked from the main login page via the identification stage.
resource "authentik_flow" "passwordless" {
  name           = "passwordless-authentication"
  title          = "Sign in with a passkey"
  slug           = "passwordless-authentication"
  designation    = "authentication"
  authentication = "none"
}

resource "authentik_flow_stage_binding" "passwordless_identification" {
  target = authentik_flow.passwordless.uuid
  stage  = authentik_stage_identification.passwordless.id
  order  = 10
}

resource "authentik_flow_stage_binding" "passwordless_webauthn" {
  target = authentik_flow.passwordless.uuid
  stage  = authentik_stage_authenticator_validate.webauthn_only.id
  order  = 20
}

resource "authentik_flow_stage_binding" "passwordless_login" {
  target = authentik_flow.passwordless.uuid
  stage  = authentik_stage_user_login.main.id
  order  = 100
}
