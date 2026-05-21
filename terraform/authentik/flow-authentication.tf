resource "authentik_flow" "authentication" {
  name        = "welcome-to-materia-wtf"
  title       = "Welcome to materia.wtf"
  slug        = "authentication"
  designation = "authentication"
  authentication = "none"
}

# ── Stage 5: Deny (reputation check) ─────────────────────────────────────────
# Shown only when reputation is BAD. The reputation policy returns True when
# the user/IP is OK — we negate it so the deny stage is shown when they're NOT ok.

resource "authentik_flow_stage_binding" "authentication_deny" {
  target             = authentik_flow.authentication.uuid
  stage              = authentik_stage_deny.reputation.id
  order              = 5
  policy_engine_mode = "all"
}

resource "authentik_policy_binding" "authentication_deny_reputation" {
  target = authentik_flow_stage_binding.authentication_deny.id
  policy = authentik_policy_reputation.block.id
  order  = 0
  negate = true   # reputation returns True=OK, so negate → show deny when NOT OK
}

# ── Stage 10: Captcha (Turnstile) ─────────────────────────────────────────────
# Shown only for remote (non-RFC1918) clients. Local network → policy returns
# False → stage skipped.

resource "authentik_flow_stage_binding" "authentication_captcha" {
  target             = authentik_flow.authentication.uuid
  stage              = authentik_stage_captcha.main.id
  order              = 10
  policy_engine_mode = "all"
}

resource "authentik_policy_binding" "authentication_captcha_remote" {
  target = authentik_flow_stage_binding.authentication_captcha.id
  policy = authentik_policy_expression.require_remote_network.id
  order  = 0
}

# ── Stage 20: Identification ──────────────────────────────────────────────────
# Always shown — no policy bindings means it always runs.

resource "authentik_flow_stage_binding" "authentication_identification" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_identification.main.id
  order  = 20
}

# ── Stage 30: Password ────────────────────────────────────────────────────────
# Skipped on local network. Remote users must enter their password.

resource "authentik_flow_stage_binding" "authentication_password" {
  target             = authentik_flow.authentication.uuid
  stage              = authentik_stage_password.main.id
  order              = 30
  policy_engine_mode = "all"
}

resource "authentik_policy_binding" "authentication_password_remote" {
  target = authentik_flow_stage_binding.authentication_password.id
  policy = authentik_policy_expression.require_remote_network.id
  order  = 0
}

# ── Stage 40: MFA Validation ──────────────────────────────────────────────────
# Skipped on local network. Remote users must pass their configured MFA device
# (TOTP via 1Password, WebAuthn passkey, or static backup code).
# Users with no MFA configured are allowed through (not_configured_action=skip).

resource "authentik_flow_stage_binding" "authentication_mfa" {
  target             = authentik_flow.authentication.uuid
  stage              = authentik_stage_authenticator_validate.mfa.id
  order              = 40
  policy_engine_mode = "all"
}

resource "authentik_policy_binding" "authentication_mfa_remote" {
  target = authentik_flow_stage_binding.authentication_mfa.id
  policy = authentik_policy_expression.require_remote_network.id
  order  = 0
}

# ── Stage 100: User Login ─────────────────────────────────────────────────────

resource "authentik_flow_stage_binding" "authentication_login" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_user_login.main.id
  order  = 100
}
