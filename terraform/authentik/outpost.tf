# ─── Embedded Outpost ─────────────────────────────────────────────────────────
#
# The embedded outpost runs inside the Authentik worker pod and handles all
# forward-auth requests from Envoy. It must explicitly list every proxy provider
# it should serve — providers created in Terraform are NOT auto-assigned.
#
# ── First-time import ────────────────────────────────────────────────────────
# Authentik creates the embedded outpost automatically on install, so we need
# to import it into Terraform state before the first apply:
#
#   OUTPOST_PK=$(curl -s \
#     -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
#     "https://auth.materia.wtf/api/v3/outposts/instances/?managed=goauthentik.io%2Foutposts%2Fembedded" \
#     | jq -r '.results[0].pk')
#   terraform import authentik_outpost.embedded "$OUTPOST_PK"
#
# Or find the UUID in: Admin UI → Outposts → authentik Embedded Outpost → Edit
# ─────────────────────────────────────────────────────────────────────────────

resource "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
  type = "proxy"

  # Every proxy provider that should be served by the embedded outpost
  protocol_providers = concat(
    [for _, v in authentik_provider_proxy.media : v.id],
    [for _, v in authentik_provider_proxy.admin : v.id],
  )

  config = jsonencode({
    authentik_host          = "https://auth.materia.wtf"
    authentik_host_insecure = false
    log_level               = "info"
    object_naming_template  = "ak-outpost-%(name)s"
    kubernetes_replicas     = 1
    kubernetes_namespace    = "security"
    kubernetes_service_type = "ClusterIP"
    kubernetes_disabled_components = []
    kubernetes_image_pull_secrets  = []
    kubernetes_ingress_annotations = {}
  })
}
