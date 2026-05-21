resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

resource "authentik_group" "media" {
  name         = "media"
  is_superuser = false
  parent       = authentik_group.users.id
}
