# ─── Deny ────────────────────────────────────────────────────────────────────

resource "authentik_stage_deny" "reputation" {
  name = "reputation-deny"
}

# ─── Identification ───────────────────────────────────────────────────────────

# Main login identification stage — links to enrollment, recovery, and
# the passwordless flow so their buttons appear on the login page.
resource "authentik_stage_identification" "main" {
  name        = "authentication-identification"
  user_fields = ["username", "email"]

  enrollment_flow   = authentik_flow.enrollment.uuid
  recovery_flow     = authentik_flow.recovery.uuid
  passwordless_flow = authentik_flow.passwordless.uuid
}

# Stripped-down identification for passwordless (no enrollment/recovery links)
resource "authentik_stage_identification" "passwordless" {
  name        = "passwordless-identification"
  user_fields = ["email"]
}

# Stripped-down identification for recovery
resource "authentik_stage_identification" "recovery" {
  name        = "recovery-identification"
  user_fields = ["email", "username"]
}

# ─── Password ─────────────────────────────────────────────────────────────────

resource "authentik_stage_password" "main" {
  name     = "authentication-password"
  backends = ["authentik.core.auth.InbuiltBackend", "authentik.core.auth.TokenBackend"]
  # failed_attempts_before_cancel feeds into reputation scoring
  failed_attempts_before_cancel = 5
}

# ─── Captcha (Cloudflare Turnstile) ──────────────────────────────────────────

resource "authentik_stage_captcha" "main" {
  name        = "authentication-captcha"
  public_key  = local.turnstile_site_key
  private_key = local.turnstile_secret_key
  # Cloudflare Turnstile endpoints (non-interactive by default)
  js_url  = "https://challenges.cloudflare.com/turnstile/v0/api.js"
  api_url = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  interactive = false
}

# ─── MFA — TOTP ──────────────────────────────────────────────────────────────

# Setup stage used in the user-settings flow (and optionally enrollment)
resource "authentik_stage_authenticator_totp" "setup" {
  name   = "authenticator-totp-setup"
  digits = 6
  # 1Password stores and auto-fills the TOTP secret when scanning the QR code
  # during setup — no Duo integration needed
}

# ─── MFA — WebAuthn (Passkey) ────────────────────────────────────────────────

resource "authentik_stage_authenticator_webauthn" "setup" {
  name                     = "authenticator-webauthn-setup"
  resident_key_requirement = "preferred"
  user_verification        = "preferred"
}

# ─── MFA — Static backup codes ───────────────────────────────────────────────

resource "authentik_stage_authenticator_static" "setup" {
  name        = "authenticator-static-setup"
  token_count = 6
}

# ─── MFA — Validate (login) ──────────────────────────────────────────────────

# Standard MFA challenge used during login — accepts TOTP, WebAuthn, or backup codes.
resource "authentik_stage_authenticator_validate" "mfa" {
  name                       = "authentication-mfa-validation"
  device_classes             = ["static", "totp", "webauthn"]
  # "skip": users without MFA configured can still log in (change to
  # "configure" to force MFA enrollment, or "deny" to block them entirely)
  not_configured_action      = "configure"
  webauthn_user_verification = "preferred"
}

# WebAuthn-only validate used by the passwordless flow
resource "authentik_stage_authenticator_validate" "webauthn_only" {
  name                       = "passwordless-mfa-validation"
  device_classes             = ["webauthn"]
  not_configured_action      = "deny"
  webauthn_user_verification = "required"
}

# ─── User Login ───────────────────────────────────────────────────────────────

resource "authentik_stage_user_login" "main" {
  name                     = "authentication-login"
  session_duration         = "seconds=0"   # expires when browser closes
  remember_me_offset       = "seconds=2592000"  # 30-day "remember me" option
  terminate_other_sessions = false
}

# ─── Enrollment ───────────────────────────────────────────────────────────────

resource "authentik_stage_invitation" "enrollment" {
  name                             = "enrollment-invitation"
  continue_flow_without_invitation = false
}

# Prompt fields
resource "authentik_stage_prompt_field" "username" {
  name        = "username"
  field_key   = "username"
  label       = "Username"
  type        = "username"
  required    = true
  placeholder = "Username"
  order       = 0
}

resource "authentik_stage_prompt_field" "name" {
  name        = "name"
  field_key   = "name"
  label       = "Full Name"
  type        = "text"
  required    = true
  placeholder = "Full Name"
  order       = 10
}

resource "authentik_stage_prompt_field" "email" {
  name        = "email"
  field_key   = "email"
  label       = "Email"
  type        = "email"
  required    = true
  placeholder = "email@example.com"
  order       = 20
}

resource "authentik_stage_prompt_field" "password" {
  name        = "password"
  field_key   = "password"
  label       = "Password"
  type        = "password"
  required    = true
  placeholder = "Password"
  order       = 30
}

resource "authentik_stage_prompt_field" "password_repeat" {
  name        = "password_repeat"
  field_key   = "password_repeat"
  label       = "Password (confirm)"
  type        = "password"
  required    = true
  placeholder = "Password (confirm)"
  order       = 40
}

resource "authentik_stage_prompt" "enrollment" {
  name = "enrollment-prompt"
  fields = [
    authentik_stage_prompt_field.username.id,
    authentik_stage_prompt_field.name.id,
    authentik_stage_prompt_field.email.id,
    authentik_stage_prompt_field.password.id,
    authentik_stage_prompt_field.password_repeat.id,
  ]
}

resource "authentik_stage_user_write" "enrollment" {
  name                     = "enrollment-user-write"
  create_users_as_inactive = false
  create_users_group       = authentik_group.users.id
}

resource "authentik_stage_email" "enrollment_verification" {
  name                     = "enrollment-email-verification"
  use_global_settings      = true   # uses email config from the Helm values / 1Password
  activate_user_on_success = true
  subject                  = "Welcome to materia.wtf — please verify your email"
  template                 = "email/account_confirmation.html"
  token_expiry             = 30
  timeout                  = 10
}

# ─── Recovery ─────────────────────────────────────────────────────────────────

resource "authentik_stage_email" "recovery" {
  name                = "recovery-email"
  use_global_settings = true
  subject             = "materia.wtf — Password Reset"
  template            = "email/password_reset.html"
  token_expiry        = 30
  timeout             = 10
}

resource "authentik_stage_prompt_field" "new_password" {
  name        = "new_password"
  field_key   = "password"
  label       = "New Password"
  type        = "password"
  required    = true
  placeholder = "New Password"
  order       = 0
}

resource "authentik_stage_prompt_field" "new_password_repeat" {
  name        = "new_password_repeat"
  field_key   = "password_repeat"
  label       = "New Password (confirm)"
  type        = "password"
  required    = true
  placeholder = "New Password (confirm)"
  order       = 10
}

resource "authentik_stage_prompt" "recovery_password" {
  name = "recovery-password-prompt"
  fields = [
    authentik_stage_prompt_field.new_password.id,
    authentik_stage_prompt_field.new_password_repeat.id,
  ]
}

resource "authentik_stage_user_write" "recovery" {
  name                     = "recovery-user-write"
  create_users_as_inactive = false
}

# ─── Invalidation (logout) ────────────────────────────────────────────────────

resource "authentik_stage_user_logout" "main" {
  name = "session-invalidation"
}

# ─── User Settings ────────────────────────────────────────────────────────────

resource "authentik_stage_prompt_field" "settings_name" {
  name        = "settings_name"
  field_key   = "name"
  label       = "Full Name"
  type        = "text"
  required    = false
  placeholder = "Full Name"
  order       = 0
}

resource "authentik_stage_prompt_field" "settings_email" {
  name        = "settings_email"
  field_key   = "email"
  label       = "Email"
  type        = "email"
  required    = false
  placeholder = "email@example.com"
  order       = 10
}

resource "authentik_stage_prompt" "user_settings" {
  name = "user-settings-prompt"
  fields = [
    authentik_stage_prompt_field.settings_name.id,
    authentik_stage_prompt_field.settings_email.id,
  ]
}

resource "authentik_stage_user_write" "user_settings" {
  name                     = "user-settings-write"
  create_users_as_inactive = false
}
