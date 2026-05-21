# ─── Reputation ──────────────────────────────────────────────────────────────

# Tracks failed logins by IP and username. Bound to the deny stage in the
# authentication flow to block brute-forced IPs/users.
resource "authentik_policy_reputation" "block" {
  name           = "reputation-block"
  threshold      = -5
  check_ip       = true
  check_username = true
}

# ─── Network ─────────────────────────────────────────────────────────────────

# Returns True when the client is on a REMOTE (non-RFC1918) network.
# Used to conditionally show password/MFA/captcha stages — if this policy
# returns False the stage is skipped, giving local users a frictionless login.
#
# Security note: this fully trusts your local network. Anyone with LAN access
# can log in as any user without a password. Only enable if your network is
# genuinely trusted (VLANs, firewall rules, etc.).
resource "authentik_policy_expression" "require_remote_network" {
  name = "require-remote-network"
  expression = <<-EOT
    from ipaddress import ip_address, ip_network

    client_ip = ip_address(request.http_request.META.get("REMOTE_ADDR", "0.0.0.0"))
    local_networks = [
        ip_network("10.0.0.0/8"),
        ip_network("172.16.0.0/12"),
        ip_network("192.168.0.0/16"),
    ]
    return not any(client_ip in net for net in local_networks)
  EOT
}
