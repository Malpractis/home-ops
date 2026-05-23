# ─── How to add a new OIDC app ───────────────────────────────────────────────
#
# 1. Create an authentik_provider_oauth2 resource with the app's redirect URI(s)
# 2. Create an authentik_application resource pointing at the provider
# 3. Run `terraform apply` and capture the client_secret output
# 4. Store client_id + client_secret in 1Password under the app's item
# 5. Add/update the ExternalSecret in the app's Kubernetes manifests to pull them
#
# For apps that have no native OIDC support, add them to the relevant
# proxy_apps local below — they'll get forward auth via the embedded outpost.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  oidc_scopes = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]

  # Forward-auth proxy apps — media group access.
  # icon paths are relative to the Authentik media root (S3: materia-authentik-media/media/public/)
  # Prefer SVG over PNG where available (application-icons/svg/ or application-icons/png/)
  media_proxy_apps = {
    radarr       = { name = "Radarr",            url = "https://radarr.materia.wtf",                   description = "Movies",             icon = "application-icons/svg/radarr.svg"                           }
    "radarr-4k"  = { name = "Radarr 4K",         url = "https://radarr-4k.materia.wtf",                description = "4K movies",          icon = "application-icons/svg/radarr-4k.svg"                        }
    radarr-anime = { name = "Radarr Anime",       url = "https://radarr-anime.materia.wtf",             description = "Anime movies",       icon = "application-icons/svg/radarr.svg"                           }
    sonarr       = { name = "Sonarr",             url = "https://sonarr.materia.wtf",                   description = "TV shows",           icon = "application-icons/svg/sonarr.svg"                           }
    sonarr-anime = { name = "Sonarr Anime",       url = "https://sonarr-anime.materia.wtf",             description = "Anime TV",           icon = "application-icons/svg/sonarr.svg"                           }
    prowlarr     = { name = "Prowlarr",           url = "https://prowlarr.materia.wtf",                 description = "Indexers",           icon = "application-icons/png/prowlarr.png"                         }
    lidarr       = { name = "Lidarr",             url = "https://lidarr.materia.wtf",                   description = "Music",              icon = "application-icons/svg/lidarr.svg"                           }
    bazarr       = { name = "Bazarr",             url = "https://bazarr.materia.wtf",                   description = "Subtitles",          icon = "application-icons/svg/bazarr.svg"                           }
    bazarr-anime = { name = "Bazarr Anime",       url = "https://bazarr-anime.materia.wtf",             description = "Anime subtitles",    icon = "application-icons/svg/bazarr.svg"                           }
    sabnzbd      = { name = "SABnzbd",            url = "https://sabnzbd.materia.wtf",                  description = "Usenet downloader",  icon = "application-icons/svg/sabnzbd.svg"                          }
    qbittorrent  = { name = "qBittorrent",        url = "https://qbittorrent.materia.wtf",              description = "Torrent client",     icon = "application-icons/svg/qbittorrent.svg"                      }
    autobrr      = { name = "autobrr",            url = "https://autobrr.materia.wtf",                  description = "Torrent automation", icon = "application-icons/svg/autobrr.svg"                          }
    notifiarr    = { name = "Notifiarr",          url = "https://notifiarr.materia.wtf",                description = "Notifications",      icon = "application-icons/png/notifiarr.png"                        }
    stash        = { name = "Stash",              url = "https://stash.materia.wtf",                    description = "Media library",      icon = "application-icons/svg/stash.svg"                            }
    calibre      = { name = "Calibre",            url = "https://calibre.materia.wtf",                  description = "eBook library",      icon = "application-icons/svg/calibre-web.svg"                      }
    calibre-dl   = { name = "Calibre Downloader", url = "https://calibre-book-downloader.materia.wtf",  description = "Book downloads",     icon = "application-icons/png/calibre-web-automated-book-downloader.png" }
    readarr      = { name = "Readarr",            url = "https://readarr.materia.wtf",                  description = "Books",              icon = "application-icons/svg/readarr.svg"                          }
  }

  # Forward-auth proxy apps — admins group access.
  admin_proxy_apps = {
    vmsingle       = { name = "VictoriaMetrics", url = "https://vmsingle.materia.wtf",       description = "Metrics",           icon = "application-icons/svg/victoriametrics.svg" }
    vmalert        = { name = "VMAlert",         url = "https://vmalert.materia.wtf",        description = "Alerting rules",    icon = "application-icons/svg/victoriametrics.svg" }
    vmalertmanager = { name = "AlertManager",    url = "https://vmalertmanager.materia.wtf", description = "Alert routing",     icon = "application-icons/svg/alertmanager.svg"    }
    status         = { name = "Status",          url = "https://status.materia.wtf",         description = "Uptime monitoring", icon = "application-icons/svg/gatus.svg"           }
    flux           = { name = "Flux",            url = "https://flux-operator.materia.wtf",  description = "GitOps operator",   icon = "application-icons/svg/flux-operator.svg"   }
    pve-0          = { name = "Proxmox",         url = "https://pve-0.materia.wtf",          description = "Hypervisor",        icon = "application-icons/png/proxmox.png"         }
    pi-0           = { name = "Pi-hole (0)",     url = "https://pi-0.materia.wtf",           description = "DNS & ad blocking", icon = "application-icons/png/pi-hole.png"         }
    pi-1           = { name = "Pi-hole (1)",     url = "https://pi-1.materia.wtf",           description = "DNS & ad blocking", icon = "application-icons/png/pi-hole.png"         }
  }
}

# ─── Forward auth — media group ──────────────────────────────────────────────

resource "authentik_provider_proxy" "media" {
  for_each      = local.media_proxy_apps
  name          = lower(each.value.name)
  mode          = "forward_single"
  external_host = each.value.url

  authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow  = authentik_flow.invalidation.uuid
}

resource "authentik_application" "media" {
  for_each          = local.media_proxy_apps
  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_proxy.media[each.key].id
  group             = authentik_group.media.name
  meta_launch_url   = each.value.url
  meta_description  = each.value.description
  meta_icon         = each.value.icon
  open_in_new_tab   = true
}

resource "authentik_policy_binding" "media" {
  for_each = local.media_proxy_apps
  target   = authentik_application.media[each.key].uuid
  group    = authentik_group.media.id
  order    = 0
}

# ─── Forward auth — admins group ─────────────────────────────────────────────

resource "authentik_provider_proxy" "admin" {
  for_each      = local.admin_proxy_apps
  name          = lower(each.value.name)
  mode          = "forward_single"
  external_host = each.value.url

  authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow  = authentik_flow.invalidation.uuid
}

resource "authentik_application" "admin" {
  for_each          = local.admin_proxy_apps
  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_proxy.admin[each.key].id
  group             = authentik_group.admins.name
  meta_launch_url   = each.value.url
  meta_description  = each.value.description
  meta_icon         = each.value.icon
  open_in_new_tab   = true
}

resource "authentik_policy_binding" "admin" {
  for_each = local.admin_proxy_apps
  target   = authentik_application.admin[each.key].uuid
  group    = authentik_group.admins.id
  order    = 0
}

# ─── Grafana — native OIDC ───────────────────────────────────────────────────

resource "authentik_provider_oauth2" "grafana" {
  name          = "grafana"
  client_id     = "grafana"
  client_type   = "confidential"
  allowed_redirect_uris = [
    {
      url           = "https://grafana.materia.wtf/login/generic_oauth"
      matching_mode = "strict"
    }
  ]

  signing_key = data.authentik_certificate_key_pair.generated.id

  authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow  = authentik_flow.invalidation.uuid

  property_mappings = local.oidc_scopes
}

resource "authentik_application" "grafana" {
  name              = "Grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana.id
  group             = authentik_group.admins.name
  meta_launch_url   = "https://grafana.materia.wtf"
  meta_description  = "Metrics & dashboards"
  meta_icon         = "application-icons/svg/grafana.svg"
  open_in_new_tab   = true
}

resource "authentik_policy_binding" "grafana_admins" {
  target = authentik_application.grafana.uuid
  group  = authentik_group.admins.id
  order  = 0
}

# After apply, store in 1Password under 'grafana' and wire up the Grafana ExternalSecret:
#   GF_AUTH_GENERIC_OAUTH_CLIENT_ID     = grafana
#   GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = <value below>
output "grafana_client_secret" {
  value     = authentik_provider_oauth2.grafana.client_secret
  sensitive = true
}

# ─── Seerr — native OIDC ─────────────────────────────────────────────────────

resource "authentik_provider_oauth2" "seerr" {
  name          = "seerr"
  client_id     = "seerr"
  client_type   = "confidential"
  allowed_redirect_uris = [
    {
      url           = "https://requests.materia.wtf/auth/oidc-callback"
      matching_mode = "strict"
    }
  ]

  signing_key = data.authentik_certificate_key_pair.generated.id

  authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow  = authentik_flow.invalidation.uuid

  property_mappings = local.oidc_scopes
}

resource "authentik_application" "seerr" {
  name              = "Seerr"
  slug              = "seerr"
  protocol_provider = authentik_provider_oauth2.seerr.id
  group             = authentik_group.media.name
  meta_launch_url   = "https://requests.materia.wtf"
  meta_description  = "Media requests"
  meta_icon         = "application-icons/png/seerr.png"
  open_in_new_tab   = true
}

resource "authentik_policy_binding" "seerr_media" {
  target = authentik_application.seerr.uuid
  group  = authentik_group.media.id
  order  = 0
}

# After apply, store in 1Password under 'seerr' and configure in Seerr settings:
#   OIDC client ID:     seerr
#   OIDC client secret: <value below>
#   Issuer URL:         https://auth.materia.wtf/application/o/seerr/
output "seerr_client_secret" {
  value     = authentik_provider_oauth2.seerr.client_secret
  sensitive = true
}

# ─── TrueNAS — native OIDC ───────────────────────────────────────────────────

resource "authentik_provider_oauth2" "truenas" {
  name          = "truenas"
  client_id     = "truenas"
  client_type   = "confidential"
  allowed_redirect_uris = [
    {
      url           = "https://nas.materia.wtf/api/v2.0/auth/oidc_callback"
      matching_mode = "strict"
    }
  ]

  signing_key = data.authentik_certificate_key_pair.generated.id

  authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
  invalidation_flow  = authentik_flow.invalidation.uuid

  property_mappings = local.oidc_scopes
}

resource "authentik_application" "truenas" {
  name              = "TrueNAS"
  slug              = "truenas"
  protocol_provider = authentik_provider_oauth2.truenas.id
  group             = authentik_group.admins.name
  meta_launch_url   = "https://nas.materia.wtf"
  meta_description  = "NAS & storage"
  meta_icon         = "application-icons/svg/truenas-scale.svg"
  open_in_new_tab   = true
}

resource "authentik_policy_binding" "truenas_admins" {
  target = authentik_application.truenas.uuid
  group  = authentik_group.admins.id
  order  = 0
}

# After apply, configure in TrueNAS: System Settings → General → Security → SSO
#   Issuer URL:    https://auth.materia.wtf/application/o/truenas/
#   Client ID:     truenas
#   Client Secret: <value below>
output "truenas_client_secret" {
  value     = authentik_provider_oauth2.truenas.client_secret
  sensitive = true
}

# ─── HTTP Basic Auth (forward auth proxy pattern) ────────────────────────────
#
# Use this for apps that cannot do OIDC natively. Authentik's embedded outpost
# sits in front and injects HTTP Basic Auth headers that the upstream app reads.
#
# resource "authentik_provider_proxy" "myapp_basic" {
#   name          = "myapp-basic-auth"
#   mode          = "forward_single"
#   external_host = "https://myapp.materia.wtf"
#
#   basic_auth_enabled            = true
#   basic_auth_username_attribute = "username"
#   basic_auth_password_attribute = "httpBasicPassword"
#
#   authorization_flow = data.authentik_flow.default_provider_authorization_implicit_consent.id
#   invalidation_flow  = authentik_flow.invalidation.uuid
# }
