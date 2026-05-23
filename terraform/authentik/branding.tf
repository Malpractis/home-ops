resource "authentik_brand" "main" {
  domain         = "auth.materia.wtf"
  default        = true
  branding_title = "Materia"

  branding_logo     = "icons/orb.svg"
  branding_favicon  = "icons/orb.png"
  flow_background   = "backgrounds/W_2013_244_GRAVITY.jpg"

  # Wire up all the custom flows
  flow_authentication = authentik_flow.authentication.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  flow_user_settings  = authentik_flow.user_settings.uuid
}
