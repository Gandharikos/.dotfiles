---
title: Seafile
description: Long-term cloud storage at cloud.huwenqiang.dev.
---

Seafile provides long-term cloud storage and synchronization at `https://cloud.huwenqiang.dev`. It
is separate from Pingvin Share X, which is used for temporary client delivery.

## Authentication

The existing administrator account is `johnson.wq.hu@gmail.com`; Seafile uses the complete email
address as its local login name. The account remains active and retains administrator privileges.
Its random bootstrap password is stored only on Athena and can be retrieved with:

```bash
ssh -t athena sudo cat /var/lib/seafile/secrets/admin-password
```

Kanidm OAuth is enabled only for the `seafile-users` group, whose declarative member is `johnson`.
On the first Kanidm login, Seafile matches the verified Kanidm email to the existing local account
and records the social-login binding; it does not create unknown OAuth users. Local password login
remains enabled as a recovery path.

The OAuth client secret is generated on Athena at `/var/lib/seafile/secrets/oidc-client-secret`. It
is readable only by root and the Kanidm service and is injected into the persistent Seahub
configuration at runtime, never into Git or the Nix store.

Useful checks:

```bash
ssh athena systemctl status podman-seafile.service seafile-oidc-config.service
ssh athena journalctl -u podman-seafile.service -u seafile-oidc-config.service
curl -fsS https://cloud.huwenqiang.dev/
```
