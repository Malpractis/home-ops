resource "authentik_flow" "recovery" {
  name           = "password-recovery"
  title          = "Password Recovery"
  slug           = "password-recovery"
  designation    = "recovery"
  authentication = "none"
}

resource "authentik_flow_stage_binding" "recovery_identification" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_identification.recovery.id
  order  = 10
}

resource "authentik_flow_stage_binding" "recovery_email" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_email.recovery.id
  order  = 20
}

resource "authentik_flow_stage_binding" "recovery_prompt" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_prompt.recovery_password.id
  order  = 30
}

resource "authentik_flow_stage_binding" "recovery_user_write" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_user_write.recovery.id
  order  = 40
}

resource "authentik_flow_stage_binding" "recovery_login" {
  target = authentik_flow.recovery.uuid
  stage  = authentik_stage_user_login.main.id
  order  = 50
}
