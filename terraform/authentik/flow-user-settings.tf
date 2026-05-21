# Users reach this flow from their profile page to update details and
# manage MFA devices (TOTP, WebAuthn passkey, backup codes).
resource "authentik_flow" "user_settings" {
  name           = "user-settings"
  title          = "User Settings"
  slug           = "user-settings"
  designation    = "stage_configuration"
  authentication = "require_authenticated"
}

# ── Profile details ───────────────────────────────────────────────────────────

resource "authentik_flow_stage_binding" "user_settings_prompt" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_prompt.user_settings.id
  order  = 10
}

resource "authentik_flow_stage_binding" "user_settings_write" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_user_write.user_settings.id
  order  = 20
}

# ── MFA device setup ──────────────────────────────────────────────────────────
# Each stage below lets the user register/manage the corresponding MFA device.
# These are shown when the user navigates to Settings > MFA Devices.

resource "authentik_flow_stage_binding" "user_settings_totp" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_authenticator_totp.setup.id
  order  = 30
}

resource "authentik_flow_stage_binding" "user_settings_webauthn" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_authenticator_webauthn.setup.id
  order  = 40
}

resource "authentik_flow_stage_binding" "user_settings_static" {
  target = authentik_flow.user_settings.uuid
  stage  = authentik_stage_authenticator_static.setup.id
  order  = 50
}
