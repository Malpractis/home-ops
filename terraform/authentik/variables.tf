# All secrets are injected as TF_VAR_* environment variables by the GHA workflow
# via the 1password/load-secrets-action. See terraform-authentik.yaml.

# ─── Cloudflare Turnstile ─────────────────────────────────────────────────────
# op://kubernetes/cloudflare-turnstile/site-key
variable "turnstile_site_key" {
  type      = string
  sensitive = true
}

# op://kubernetes/cloudflare-turnstile/secret-key
variable "turnstile_secret_key" {
  type      = string
  sensitive = true
}

# ─── Discord OAuth ────────────────────────────────────────────────────────────
# op://kubernetes/discord-oauth/client-id
variable "discord_client_id" {
  type      = string
  sensitive = true
}

# op://kubernetes/discord-oauth/client-secret
variable "discord_client_secret" {
  type      = string
  sensitive = true
}

# ─── Google OAuth ─────────────────────────────────────────────────────────────
# op://kubernetes/google-oauth/client-id
variable "google_client_id" {
  type      = string
  sensitive = true
}

# op://kubernetes/google-oauth/client-secret
variable "google_client_secret" {
  type      = string
  sensitive = true
}

# ─── GitHub OAuth ─────────────────────────────────────────────────────────────
# op://kubernetes/github-oauth/client-id
variable "github_client_id" {
  type      = string
  sensitive = true
}

# op://kubernetes/github-oauth/client-secret
variable "github_client_secret" {
  type      = string
  sensitive = true
}

# ─── Plex ─────────────────────────────────────────────────────────────────────
# op://kubernetes/plex-oauth/client-id  (a UUID you generated, not a Plex credential)
variable "plex_client_id" {
  type      = string
  sensitive = true
}
