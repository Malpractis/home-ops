# proton-mail-bridge-relay

In-cluster SMTP for app notifications, backed by Proton Mail — no Gmail.

```
app ──:25, no auth, no TLS──▶ postfix ──:1025 + auth + STARTTLS──▶ bridge ──▶ Proton
```

One pod, two containers: **Postfix** (the relay apps talk to) and **Proton Mail
Bridge** (authenticates to Proton). Apps point at a single plain endpoint:

```
smtp://proton-mail-bridge-relay.default.svc.cluster.local:25
```

No username, no password, no TLS on the app side — Postfix holds the only
credentials and terminates STARTTLS to Bridge.

## Prerequisites

- A **paid Proton plan** (Mail Plus / Unlimited / Business). Bridge does not work
  on free accounts.
- A 1Password item named **`proton-mail-bridge`** (the ExternalSecret reads from
  it). Leave the credential fields blank for now — they're generated in step 3.

## First-time setup

These steps are **manual and one-off** — Bridge's login is interactive and its
keychain is not reproducible from Git.

### 1. Deploy

Already wired into `kubernetes/apps/default/kustomization.yaml`. Commit and let
Flux reconcile. The `bridge` container will be running but **not logged in** yet,
so Postfix can't relay until step 3–4.

### 2. Exec into Bridge

```sh
kubectl -n default exec -it deploy/proton-mail-bridge-relay -c bridge -- /bin/sh
```

### 3. Log in and grab the generated credentials

```sh
pkill bridge          # stop the auto-started instance
/usr/bin/bridge --cli
>>> login             # enter Proton email + password + 2FA
>>> info              # copy the SMTP username + password it prints
>>> exit
```

Bridge generates its **own** SMTP username/password (not your Proton login).
These are what Postfix uses upstream. The encrypted keychain is written to the
volsync-backed PVC mounted at `/root`, so it survives pod restarts.

### 4. Store the credentials and refresh

Put the values from `info` into the **`proton-mail-bridge`** 1Password item:

| 1Password field    | Value from `bridge info` |
| ------------------ | ------------------------ |
| `BRIDGE_SMTP_USER` | SMTP username            |
| `BRIDGE_SMTP_PASS` | SMTP password            |

The ExternalSecret maps these to `RELAYHOST_USERNAME` / `RELAYHOST_PASSWORD` in
`proton-mail-bridge-relay-secret`. Restart so Postfix picks them up:

```sh
kubectl -n default rollout restart deploy/proton-mail-bridge-relay
```

### 5. Test

```sh
kubectl -n default run smtp-test --rm -it --restart=Never --image=alpine -- \
  sh -c 'apk add --no-cache swaks && \
    swaks --server proton-mail-bridge-relay.default.svc:25 \
          --from noreply@materia.wtf --to you@materia.wtf \
          --header "Subject: relay test" --body "it works"'
```

A message should land in your Proton inbox.

## Pointing apps at it

Configure each app's SMTP settings as:

| Setting     | Value                                                  |
| ----------- | ------------------------------------------------------ |
| Host        | `proton-mail-bridge-relay.default.svc.cluster.local`   |
| Port        | `25`                                                   |
| Encryption  | None                                                   |
| Username    | _(leave blank)_                                        |
| Password    | _(leave blank)_                                        |
| From / Sender | an address under `materia.wtf`                       |

The relay only accepts connections from the cluster pod network
(`10.42.0.0/16`) and only relays mail `From` `materia.wtf` — see
`ALLOWED_SENDER_DOMAINS` / `MYNETWORKS` in `app/helmrelease.yaml`.
