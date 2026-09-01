---
title: Outline Wiki
description: Internal knowledge base at wiki.huwenqiang.dev.
---

Outline is the internal knowledge base at `https://wiki.huwenqiang.dev`. Athena runs the Outline
1.9.2 package pinned by this flake's nixpkgs revision. Updates happen through the normal flake lock,
build, and deployment workflow; no mutable installation or container is involved.

## Architecture

Caddy terminates public HTTPS and proxies Outline to port 3002 on Athena. Port 3002 is not opened by
the firewall. Caddy's native reverse proxy preserves the forwarded scheme, host, and client address
and supports Outline's WebSocket-based realtime collaboration without additional header rules.

Outline uses the NixOS module's local integrations:

- PostgreSQL database and peer-authenticated user `outline` over `/run/postgresql`.
- A dedicated Redis instance with TCP disabled and socket `/run/redis-outline/redis.sock`.
- Attachments below `/var/lib/outline/data`, owned by the dedicated `outline` account with mode
  `0700`.
- Module-generated application secrets in `/var/lib/outline/secret_key` and
  `/var/lib/outline/utils_secret`.

The native module runs database migrations during normal application startup. Do not add a second
migration unit.

The upstream application does not currently provide a listen-address setting, so its socket binds to
all host interfaces on port 3002. The port remains unreachable from the Internet because it is
absent from the NixOS firewall allow-list; only Caddy targets it through `127.0.0.1`.

## Authentication and bootstrap

Outline uses OIDC Discovery at `https://sso.huwenqiang.dev/oauth2/openid/outline`. The client uses
Authorization Code flow with PKCE S256 and Kanidm's ES256 signing keys. The callback is
`https://wiki.huwenqiang.dev/auth/oidc.callback`. Legacy crypto and insecure PKCE exceptions are not
enabled.

Only members of the Kanidm group `outline-users` can authenticate. Initially that group contains
only `johnson`. The first user to successfully sign in to a new Outline instance becomes its
administrator, so Johnson must complete the first login before adding other members. To authorize a
new user later, add the Kanidm person to `outline-users` declaratively and redeploy; do not create
users by modifying the Outline database.

The single SOPS key is `oauth2-outline` in `secrets/services/kanidm.yaml`. At activation, sops-nix
creates a Kanidm-readable secret file and a separate `0400`, `outline`-owned environment file.
Neither the OAuth client secret nor the rendered environment file enters the Nix store.

## Storage, limits, and backups

Attachments use local storage because this deployment does not need S3 or MinIO. Individual uploads
are limited to 262,144,000 bytes (250 MiB), matching the current upstream recommendation. Caddy has
no separate request-body limit.

The existing Restic job includes `/var/lib/outline`, which protects attachments and both persistent
application secrets. Its pre-backup PostgreSQL dump includes the Outline database. The portable
self-hosted export and Taildrop copy include the same state. Restoring only the attachment directory
without its database and cryptographic keys is not a complete recovery.

Transactional mail is submitted without authentication to Postfix on `127.0.0.1:25`. Postfix then
uses the existing SMTP2Go relay and SOPS-managed relay credential; Outline does not receive or
duplicate that credential.

## Deployment and DNS

Build and deploy Athena with:

```bash
nix build --no-link .#nixosConfigurations.athena.config.system.build.toplevel
just deploy athena
```

DNS is not declaratively managed by this repository. Create an A and/or AAAA record for
`wiki.huwenqiang.dev` pointing to Athena before expecting Caddy to obtain a certificate.

## Verification

On Athena:

```bash
systemctl status outline redis-outline postgresql caddy
journalctl -u outline -b
sudo -u postgres psql -lqt | grep outline
redis-cli -s /run/redis-outline/redis.sock ping
ss -lntp | grep ':3002'
curl -fsS http://127.0.0.1:3002/_health
```

From a client:

```bash
curl -fsS https://sso.huwenqiang.dev/oauth2/openid/outline/.well-known/openid-configuration
curl -I https://wiki.huwenqiang.dev
```

In a browser, select **Continue with Kanidm**, authenticate as Johnson, and confirm the callback
returns to Outline without a redirect loop. Then create and edit a document, upload an image, open
the same document in a second session to test realtime editing, and sign out. Confirm the first
account has administrator privileges before expanding `outline-users`.

Outline health is checked by the existing Gatus service at `/_health`; this endpoint verifies both
PostgreSQL and Redis. Normal logs are available through `journalctl -u outline`.

## Troubleshooting

- A missing login button usually means the OIDC environment file was not installed. Check
  `systemctl status sops-install-secrets outline` without printing the environment file.
- An invalid redirect error means Kanidm's client callback does not exactly match
  `https://wiki.huwenqiang.dev/auth/oidc.callback`.
- A `502` from Caddy means Outline is not healthy on port 3002; inspect its journal and both local
  database services.
- If uploads fail, check free disk space and permissions below `/var/lib/outline/data`, followed by
  the Outline journal. Caddy does not impose an upload limit.
