resource "authentik_flow" "invalidation" {
  name           = "default-session-invalidation"
  title          = "Signing out…"
  slug           = "invalidation"
  designation    = "invalidation"
  authentication = "require_authenticated"
}

resource "authentik_flow_stage_binding" "invalidation_logout" {
  target = authentik_flow.invalidation.uuid
  stage  = authentik_stage_user_logout.main.id
  order  = 10
}
