# Invitation-only enrollment. An admin generates an invite link from the
# Authentik UI (or via API); anyone without a valid invite token is blocked.
resource "authentik_flow" "enrollment" {
  name           = "enrollment-invitation"
  title          = "Welcome to Materia"
  slug           = "enrollment-invitation"
  designation    = "enrollment"
  authentication = "none"
}

resource "authentik_flow_stage_binding" "enrollment_invitation" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_invitation.enrollment.id
  order  = 10
}

resource "authentik_flow_stage_binding" "enrollment_prompt" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_prompt.enrollment.id
  order  = 20
}

resource "authentik_flow_stage_binding" "enrollment_user_write" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_write.enrollment.id
  order  = 30
}

resource "authentik_flow_stage_binding" "enrollment_email_verification" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_email.enrollment_verification.id
  order  = 40
}

resource "authentik_flow_stage_binding" "enrollment_login" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_login.main.id
  order  = 100
}
