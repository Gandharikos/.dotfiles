---
title: Pingvin Share X
description: Temporary client file delivery at share.huwenqiang.dev.
---

Pingvin Share X provides temporary client file delivery at `https://share.huwenqiang.dev`. It is
separate from Seafile at `cloud.huwenqiang.dev`, which is intended for long-term cloud storage and
synchronization.

## Architecture

The `ghcr.io/smp46/pingvin-share-x:v1.22.1` OCI image runs with Podman on Athena. Its bundled Caddy
is disabled. The host Caddy routes `/api/*` to the API on `127.0.0.1:8089` and all other requests to
the frontend on `127.0.0.1:3005`. Neither application port is exposed publicly.

Persistent state is stored below `/var/lib/pingvin-share-x`:

- `data/` contains the SQLite database and uploaded files.
- `images/` contains application branding images.
- `state-backup/` contains a consistent daily SQLite snapshot for Restic.

Temporary uploaded videos are deliberately excluded from Restic. The declarative configuration is
recoverable from this repository, while the daily SQLite snapshot preserves users and share metadata
without silently adding potentially hundreds of gigabytes of temporary media to backups.

## Accounts and access

Public registration and anonymous share creation are disabled. Clients can open random share URLs
and download their files without an account. Password-protected shares remain available.

On the first deployment, a host-side preparation service generates a random bootstrap password in
`/var/lib/pingvin-share-x/secrets/admin-password`. Pingvin's supported `initUser` mechanism creates
the administrator `johnson`; public registration remains disabled throughout. Retrieve the password
over SSH without copying it into Git:

```bash
ssh -t athena sudo cat /var/lib/pingvin-share-x/secrets/admin-password
```

Sign in and change this bootstrap password immediately.

After signing in as `johnson`, open **Administration → Users** to create `michael` and future
employees. Employee credentials and account lists are managed in Pingvin's web interface and must
not be added to Nix or Git. Use unique strong temporary passwords and have users change them after
first login.

Only the administrator `johnson` is authorized through Kanidm. Pingvin OAuth registration remains
disabled, so Kanidm cannot create employee accounts. On the first use, sign in to Pingvin with the
local bootstrap account, open **Account**, and link the **OpenID** provider. After linking,
`johnson` can sign in through Kanidm. Local password login remains enabled as a recovery path; test
Kanidm in a separate browser session before relying on it. The OIDC client secret is generated on
Athena at `/var/lib/pingvin-share-x/secrets/oidc-client-secret` and never enters Git or the Nix
store.

Employees sign in, select one or more files, choose an expiration no longer than 30 days, create the
share, and send its random URL to the client. Reverse shares remain enabled for a future
client-to-employee upload workflow.

## Expiration and deletion

The default expiration is 14 days and the maximum is 30 days. File retention after expiration or
manual deletion is zero days. In v1.22.1, the backend cleanup job runs every minute. It calls the
file provider to recursively remove the share's physical upload directory, then deletes the share
database record. Expired shares therefore do not merely become hidden. A share may remain on disk
until the next successful cleanup run, normally less than one minute.

Unfinished shares older than one day are checked every six hours. Temporary upload chunks older than
one day are cleaned daily. Monitor container logs for `Deleted ... expired shares` if cleanup is in
doubt.

## Limits and storage safety

The maximum total share size is 50,000,000,000 bytes (50 GB). Pingvin uploads in 10 MB chunks and
checks free space before appending each chunk. There is no separate per-file cap below the total
share limit. ZIP compression is disabled because client video files are already compressed; ZIP
downloads remain available without wasting CPU on recompression. Host Caddy has no configured
request-body limit and proxies streaming responses and WebSocket upgrades by default.

Caddy has no access to the upload directory and never serves it as static content. Files are only
read through Pingvin's share authorization logic. Persistent directories use mode `0750`, and the
container runs as numeric UID/GID 10001 rather than as root after initialization.

## Operations

Deploy or update the service with:

```bash
just deploy athena
```

To update Pingvin Share X, change the explicit image tag in
`modules/nixos/services/selfhosted/pingvin-share.nix`, review the upstream release notes and
configuration schema, build Athena, and deploy it. Never replace the tag with `latest`.

Useful checks:

```bash
ssh athena systemctl status podman-pingvin-share.service
ssh athena podman healthcheck run pingvin-share
ssh athena journalctl -u podman-pingvin-share.service
ssh athena ss -lntp
curl -fsS https://share.huwenqiang.dev/api/health
```

The service is also checked by the existing Gatus deployment. A daily `sqlite3 .backup` snapshot is
written before Restic processes the state-backup directory.

The v1.22.1 all-in-one image does not exit in response to Podman's `SIGTERM`. Podman waits the
configured 30 seconds and then stops it with `SIGKILL`; systemd subsequently starts a healthy new
container. Persistent files and SQLite remain on the host, but plan maintenance restarts outside an
active upload window and keep the daily SQLite snapshot healthy.

SMTP is intentionally disabled for the first deployment. It can later use the existing SMTP2Go
service, but its password must be supplied through SOPS and a runtime-generated configuration file;
never place it directly in Nix. ClamAV, S3, MinIO, WebDAV, and other storage protocols are not part
of this deployment.
