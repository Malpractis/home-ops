resource "authentik_brand" "main" {
  domain         = "auth.materia.wtf"
  default        = true
  branding_title = "materia.wtf"

  # Wire up all the custom flows
  flow_authentication = authentik_flow.authentication.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  flow_user_settings  = authentik_flow.user_settings.uuid

  # Uncomment and upload media files to S3 to set custom logo/favicon:
  # branding_logo    = "/media/branding/logo.svg"
  # branding_favicon = "/media/branding/favicon.png"
}
