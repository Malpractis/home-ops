# ─── OAuth2 Sources — Social / Federated Login ───────────────────────────────
#
# Lets existing Authentik users link a social account and log in without a
# password. New accounts are NOT auto-created — the enrollment flow still
# requires an invitation token, so only invited users can register via social.
#
# ── Setup checklist ──────────────────────────────────────────────────────────
#
#   Discord (https://discord.com/developers/applications)
#     → New Application → OAuth2 → add redirect:
#       https://auth.materia.wtf/source/oauth/callback/discord/
#     → Bot scopes: identify email guilds
#     → Store in 1Password (vault: kubernetes, title: discord-oauth):
#         client-id, client-secret
#
#   Google (https://console.cloud.google.com/apis/credentials)
#     → Create OAuth 2.0 Client ID (Web application) → add redirect:
#       https://auth.materia.wtf/source/oauth/callback/google/
#     → Required scopes: openid email profile
#     → Store in 1Password (vault: kubernetes, title: google-oauth):
#         client-id, client-secret
#
#   GitHub (https://github.com/settings/developers → OAuth Apps)
#     → Callback URL: https://auth.materia.wtf/source/oauth/callback/github/
#     → Required scopes: read:user user:email
#     → Store in 1Password (vault: kubernetes, title: github-oauth):
#         client-id, client-secret
#
#   Plex — generate a UUID once (e.g. `python3 -c "import uuid; print(uuid.uuid4())"`)
#     → Store in 1Password (vault: kubernetes, title: plex-oauth):
#         client-id   ← the UUID (not a Plex credential — identifies this Authentik instance)
# ─────────────────────────────────────────────────────────────────────────────

# Authentik's built-in post-social-login flow — creates the user session
# without re-running password/MFA (the social provider already authenticated them)
data "authentik_flow" "default_source_authentication" {
  slug = "default-source-authentication"
}

# ─── 1Password data sources ───────────────────────────────────────────────────

data "onepassword_item" "discord_oauth" {
  vault = "kubernetes"
  title = "discord-oauth"
}

data "onepassword_item" "google_oauth" {
  vault = "kubernetes"
  title = "google-oauth"
}

data "onepassword_item" "github_oauth" {
  vault = "kubernetes"
  title = "github-oauth"
}

data "onepassword_item" "plex_oauth" {
  vault = "kubernetes"
  title = "plex-oauth"
}

locals {
  op_discord = { for f in data.onepassword_item.discord_oauth.field : f.label => f.value }
  op_google  = { for f in data.onepassword_item.google_oauth.field : f.label => f.value }
  op_github  = { for f in data.onepassword_item.github_oauth.field : f.label => f.value }
  op_plex    = { for f in data.onepassword_item.plex_oauth.field : f.label => f.value }
}

# ─── Discord ─────────────────────────────────────────────────────────────────

resource "authentik_source_oauth" "discord" {
  name    = "Discord"
  slug    = "discord"
  enabled = true

  provider_type   = "discord"
  consumer_key    = local.op_discord["client-id"]
  consumer_secret = local.op_discord["client-secret"]

  # Match to an existing Authentik user by email — social login does NOT
  # create new accounts on its own; an invitation is still required.
  user_matching_mode = "email_link"

  authentication_flow = data.authentik_flow.default_source_authentication.id
  enrollment_flow     = authentik_flow.enrollment.uuid
}

# ─── Google ──────────────────────────────────────────────────────────────────

resource "authentik_source_oauth" "google" {
  name    = "Google"
  slug    = "google"
  enabled = true

  provider_type   = "google"
  consumer_key    = local.op_google["client-id"]
  consumer_secret = local.op_google["client-secret"]

  user_matching_mode = "email_link"

  authentication_flow = data.authentik_flow.default_source_authentication.id
  enrollment_flow     = authentik_flow.enrollment.uuid
}

# ─── GitHub ──────────────────────────────────────────────────────────────────

resource "authentik_source_oauth" "github" {
  name    = "GitHub"
  slug    = "github"
  enabled = true

  provider_type   = "github"
  consumer_key    = local.op_github["client-id"]
  consumer_secret = local.op_github["client-secret"]

  user_matching_mode = "email_link"

  authentication_flow = data.authentik_flow.default_source_authentication.id
  enrollment_flow     = authentik_flow.enrollment.uuid
}

# ─── Plex ────────────────────────────────────────────────────────────────────
#
# Plex uses its own authentication protocol rather than standard OAuth2.
# The client_id here is a UUID YOU generate (not a Plex credential) — it
# identifies this Authentik instance in Plex's authorized apps list.
# Set allow_friends = true if you want Plex friends to be able to log in.

resource "authentik_source_plex" "plex" {
  name    = "Plex"
  slug    = "plex"
  enabled = true

  client_id     = local.op_plex["client-id"]
  allow_friends = false

  user_matching_mode = "email_link"

  authentication_flow = data.authentik_flow.default_source_authentication.id
  enrollment_flow     = authentik_flow.enrollment.uuid
}
