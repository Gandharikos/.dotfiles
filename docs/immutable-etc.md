# Immutable `/etc`

## Status

**STATUS: KEEP `mutable=true` FOR NOW**

`ymir` already runs the NixOS overlay `/etc` implementation, but with a writable upper layer. The
pinned nixpkgs option defaults to that Stage 1 state, and the repository prepares Userborn to keep
its account database under persistent `/var/lib/nixos` after the next boot. Do not set
`mutable = false` until the blockers below have been remediated and a fresh Stage 1 boot has been
audited.

Immutable `/etc` is primarily a declarative-state and configuration-drift feature. It is **not a
complete security boundary against root**. A sufficiently privileged process can still attack the
kernel, runtime memory, mount namespaces, services, writable filesystems, and future boot state.

## Architecture

### Current Stage 1

```text
NixOS environment.etc
        ↓
ERoFS metadata + /nix/store-backed data lower layers
        ↓
overlayfs + /.rw-etc/{upper,work}
        ↓
/etc (writable)
```

The root filesystem is tmpfs, so `/.rw-etc` is ephemeral and records writes from the current boot.
Persistent state is supplied separately from the encrypted Btrfs `/persist` subvolume through the
Preservation module.

### Intended Stage 2

```text
/nix/store
    ↓
generated ERoFS metadata + data lower layers
    ↓
read-only overlay filesystem
    ↓
/etc

persistent mutable state
    ↓
/persist-backed /var/lib/... or another explicit state directory
```

The end state should reject manual and daemon writes to `/etc`, while `nixos-rebuild` remains able
to atomically replace the generated `/etc` view.

## Current configuration

The repository's shared experimental module enables:

```nix
boot.initrd.systemd.enable = true;
services.userborn.enable = true;

system.etc.overlay.enable = true;
```

At the pinned nixpkgs revision, `system.etc.overlay.mutable` defaults to `true`; it is intentionally
left at that default during Stage 1.

For `ymir`, Stage 1 also declares:

```nix
services.userborn.passwordFilesLocation = "/var/lib/nixos";
users.mutableUsers = false;
```

The live system will continue using `/etc` as Userborn's backing directory until it boots the new
configuration. `/var/lib` is already preserved wholesale, so `/var/lib/nixos` is persistent.

The system uses Preservation, not Impermanence:

```nix
dot.persistence.enable = true;
preservation.enable = true;
preservation.preserveAt."/persist" = { ... };
```

The root is tmpfs. `/persist` and `/var/log` are encrypted Btrfs subvolumes, and `/var/lib` is a
bind mount backed by `/persist/var/lib`.

## Pinned nixpkgs implementation

This audit is based on the nixpkgs revision locked by the flake, not upstream `master`.

### Overlay construction

The pinned `nixos/modules/system/etc/etc.nix` implementation builds:

- an ERoFS metadata image containing metadata and small inline files;
- an `etcBasedir` data layer for larger regular files;
- an overlay lower directory consisting of `/run/nixos-etc-metadata::/etc-basedir`.

The systemd initrd locates those artifacts from the selected system generation and mounts the ERoFS
metadata image at `/run/nixos-etc-metadata`.

With `mutable = true`, initrd creates and uses:

```text
/sysroot/.rw-etc/upper
/sysroot/.rw-etc/work
```

and mounts `/etc` read-write. Stale overlay opaque markers are cleared when changing generations.

With `mutable = false`, no upper/work directories are included and the overlay is mounted with `ro`.
The generated lower view is the only `/etc` content.

During `nixos-rebuild switch`, the activation code mounts the new metadata image and a temporary
private overlay, moves existing submounts onto it, moves the new overlay beneath the old `/etc`, and
lazily unmounts the old view. With immutable `/etc`, an `/etc` submount is skipped if its mountpoint
is not declared in the generated lower view.

The pinned implementation asserts that overlay `/etc` uses a systemd initrd. Immutable mode also
requires Userborn or systemd-sysusers. A switchable system requires Linux 6.6 or newer.

### Userborn

The pinned Userborn module defaults `passwordFilesLocation` to `/etc` while the overlay is writable,
but to `/var/lib/nixos` when the overlay is immutable and Userborn is non-static. The location is
made explicit on `ymir` before Stage 2.

Userborn writes `passwd`, `group`, and `shadow` to the backing location and exposes direct symlinks
under `/etc`. `subuid` and `subgid` are bind-mounted because `newuidmap` rejects symlinks. With
`users.mutableUsers = false`, Userborn bind-mounts the backing files read-only after updating them.

`services.userborn.static` remains `false`; static mode is unsuitable for a switchable desktop and
requires manually managed static IDs.

A read-only simulation generated all five account files from the active Userborn JSON into a
temporary directory. `passwd`, `group`, `shadow`, `subuid`, and `subgid` were byte-identical to the
live files, including all UID/GID and subordinate-ID allocations. No account file was modified.

## Live `/etc` audit

At audit time, `findmnt` showed:

```text
/etc overlay rw,...,lowerdir=/run/nixos-etc-metadata::/etc-basedir,
  upperdir=/sysroot/.rw-etc/upper,workdir=/sysroot/.rw-etc/work
```

The live upper directory contained only the entries classified below. Root-only directories were
also enumerated without reading secret contents.

| Upper entry                                                  | Class | Creator/purpose                                                                  | Stage 2 disposition                                                                                                         |
| ------------------------------------------------------------ | ----- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `passwd`, `group`, `shadow`, `subuid`, `subgid`, `.pwd.lock` | A/B/C | Userborn account database and lock                                               | Pending next boot: originals move to persistent `/var/lib/nixos`; generated `/etc` links/mountpoints remain                 |
| empty `machine-id` plus `/etc/machine-id` bind mount         | B     | Preservation supplies the stable machine identity from `/persist/etc/machine-id` | Identity is stable; the final bind mount must be verified read-only before Stage 2                                          |
| `NetworkManager/system-connections`                          | B/D   | Preservation mountpoint for four persistent NetworkManager profiles              | Blocking: migrate profiles/secrets to a declarative or non-`/etc` NetworkManager design first                               |
| `asusd`                                                      | B/D   | Preservation mountpoint; asusd generated three hardware configuration files      | Blocking: use pinned `services.asusd.*Config` options or another supported state location, and verify daemon write behavior |
| `mullvad-vpn`                                                | B/D   | Persistent Mullvad account/device/settings state                                 | Blocking: Mullvad currently expects mutable `/etc/mullvad-vpn`                                                              |
| `tuned/*`, `modprobe.d/tuned.conf`                           | D     | TuneD runtime-selected profile/mode and generated modprobe state                 | Blocking: relocate state or replace/disable TuneD before immutable mode                                                     |
| `localtime`                                                  | A/D   | `automatic-timezoned` changes the timezone through systemd-timedated             | Blocking: choose a declarative timezone or a supported runtime-only timezone mechanism                                      |
| `.updated`                                                   | C     | systemd update completion stamp                                                  | Ephemeral; verify the pinned systemd behavior under immutable mode                                                          |
| `credstore`, `credstore.encrypted`                           | C     | Empty systemd-tmpfiles credential-store directories                              | Declare suitable lower-layer directories or verify a runtime-directory mechanism                                            |
| `avahi/services`                                             | C     | Empty `ConfigurationDirectory=avahi/services` created for Avahi                  | Verify/declare the directory before Stage 2                                                                                 |
| `nixos`                                                      | B     | Empty legacy Preservation mountpoint                                             | Remove the mount declaration after confirming no host relies on `/etc/nixos`; do not delete its backing directory blindly   |
| `tuned/profiles`                                             | A/D   | TuneD tmpfiles directory for local profiles                                      | Blocking together with TuneD runtime state                                                                                  |

No unexplained regular file containing unknown state remains, but several known daemon
incompatibilities are unresolved. Therefore the readiness criteria for Stage 2 are not met.

## State locations and compatibility

### Accounts

- Live before the next boot: account originals are under the writable overlay and individually
  bind-mounted read-only by Userborn.
- Staged Stage 1: originals are generated under `/var/lib/nixos`, which is backed by `/persist`.
- `users.mutableUsers = false`; existing UID/GID allocations are unchanged.

### Machine identity

`/etc/machine-id` is a regular 33-byte file bind-mounted from the encrypted persistent subvolume.
Its value was intentionally not included in the audit or this document. The file predates the
current boot and is stable.

Preservation mounts it during initrd. The repository suppresses the ordinary
`systemd-machine-id-commit.service` because the identity is already persistent. The pinned immutable
`/etc` implementation provides an empty regular-file placeholder suitable for either systemd's
runtime machine-id overlay or a persistent bind mount.

Before Stage 2, verify that the persistent bind mount is read-only without breaking first-boot
initialization. Do not replace it with an ad-hoc symlink.

### Networking and Wi-Fi

`ymir` uses NetworkManager with iwd as its Wi-Fi backend. systemd-networkd is also enabled for
explicitly declared links such as Tailscale, but it does not replace NetworkManager for Wi-Fi.

NetworkManager's pinned NixOS module explicitly configures keyfile storage at
`/etc/NetworkManager/system-connections`. Four existing profiles are persisted from `/persist` and
may contain credentials. Their contents were not printed or copied. Immutable mode must not be
enabled until those profiles are migrated safely, likely using NetworkManager's declarative
`ensureProfiles` support with secrets supplied outside the Nix store, or another audited supported
state path.

Other relevant network state:

- iwd state uses `/var/lib/iwd` and is covered by persistent `/var/lib`;
- Tailscale uses `/var/lib/tailscale` and `/run/tailscale`;
- Mullvad remains a blocker because its persistent state is under `/etc/mullvad-vpn`;
- SSH listens through the NixOS OpenSSH socket configuration and uses key-only authentication.

### SSH and SOPS

SSH host keys live directly under `/persist/etc/ssh`; `services.openssh.hostKeys` references those
paths instead of relying on writes to `/etc/ssh`. The same persistent ED25519 host key is used as a
sops-nix age identity. No private key content was read or copied.

### Other persistent state

Because `/var/lib` is preserved wholesale, the following currently survive the tmpfs root:

- Bluetooth pairings under `/var/lib/bluetooth`;
- fwupd state under `/var/lib/fwupd`;
- systemd random seed, timers, rfkill and related state;
- Docker state under `/var/lib/docker`;
- Tailscale state;
- Userborn state and the staged `/var/lib/nixos` account database.

fwupd declares `/etc/fwupd` writable in its service sandbox even though no corresponding upper entry
was observed in this boot. Firmware-update behavior must be tested before Stage 2.

### Secure Boot and Measured Boot

Lanzaboote Secure Boot and measured boot are enabled. The measured PCR set is 0, 4, and 7, and
automatic TPM enrollment for LUKS remains disabled.

The entire `/var/lib` tree is persistent, including:

```text
/var/lib/sbctl
/var/lib/pcrlock.d
/var/lib/systemd/pcrlock.json
```

The active pcrlock policy service completed successfully. This migration does not move or regenerate
Secure Boot keys, alter TPM state, reset PCR policy, or change LUKS/FIDO2 enrollment.

## Stage 1 deployment and verification

Build validation is safe, but the account backing-location transition should first be installed for
the next boot rather than activated casually in a running desktop session:

```bash
just check
nix build --no-link .#nixosConfigurations.ymir.config.system.build.toplevel
sudo nixos-rebuild boot --flake .#ymir
```

Do not reboot automatically. Confirm the new boot entry exists, then reboot intentionally with the
recovery passphrase and an older Lanzaboote generation available.

After boot, verify at minimum:

```bash
findmnt /etc
findmnt /etc/passwd /etc/group /etc/shadow /etc/subuid /etc/subgid
readlink /etc/passwd /etc/group /etc/shadow
sudo find /var/lib/nixos -maxdepth 1 -printf '%M %u:%g %p\n'
systemctl status userborn --no-pager
systemctl --failed
journalctl -p warning..alert -b --no-pager
sudo find /.rw-etc/upper -xdev -printf '%M %u:%g %p\n'
```

Expected Stage 1 results:

- `/etc` remains an `rw` overlay;
- `passwd`, `group`, and `shadow` point to `/var/lib/nixos`;
- `subuid` and `subgid` are bind-mounted from `/var/lib/nixos`;
- Userborn succeeds and login, `run0`, SSH, Wi-Fi, DNS and the desktop still work;
- UID/GID allocations remain unchanged;
- the new upper-layer audit still exposes every attempted `/etc` mutation.

Also verify Bluetooth, Mullvad, Docker, fwupd, Secure Boot and measured boot where applicable.

## Remaining blockers before Stage 2

1. Complete and validate the Userborn backing-location transition after a real boot.
2. Migrate NetworkManager profiles without exposing Wi-Fi credentials or losing connectivity.
3. Resolve asusd's runtime configuration writes.
4. Resolve Mullvad's hard-coded `/etc` state.
5. Relocate or replace TuneD runtime state.
6. Replace automatic timezone mutation with a declarative or runtime-only design.
7. Verify machine-id is stable and presented read-only.
8. Handle empty credential-store and Avahi configuration directories declaratively.
9. Test fwupd behavior with immutable `/etc`.
10. Reboot Stage 1 and obtain a clean, fully classified upper-layer audit with no failed units.

Only after all items are resolved should `system.etc.overlay.mutable` change to `false`.

## Stage 2 verification

When a later audit establishes readiness, build and install the immutable configuration for the next
boot. Do not use `switch` for the first transition:

```bash
just check
nix build --no-link .#nixosConfigurations.ymir.config.system.build.toplevel
sudo nixos-rebuild boot --flake .#ymir
```

After the intentional reboot:

```bash
findmnt /etc
sudo touch /etc/immutable-etc-test
```

The write must fail with `Read-only file system`. If it succeeds, do not remove the file as though
the test passed; investigate why `/etc` is writable. Then test a harmless declarative
`environment.etc` change through a normal rebuild and remove that test change from the repository.

## Recovery and rollback

Lanzaboote retains eight boot generations. Before the first Stage 2 boot, confirm an older Stage 1
generation is present in the boot menu.

If immutable `/etc` prevents normal operation:

1. Reboot and select the previous NixOS generation in the Lanzaboote/systemd-boot menu.
2. In the repository, restore:

   ```nix
   system.etc.overlay.mutable = true;
   ```

3. Build first, then install for the next boot:

   ```bash
   nix build --no-link .#nixosConfigurations.ymir.config.system.build.toplevel
   sudo nixos-rebuild boot --flake .#ymir
   ```

4. Reboot intentionally and re-audit `/.rw-etc/upper`.

If normal generations do not boot, use the NixOS installer/recovery environment, unlock the existing
LUKS volume using the recovery passphrase or configured FIDO2 method, mount the Btrfs subvolumes and
ESP, and repair or roll back the system profile. Follow `docs/boot-security.md`; do not regenerate
Secure Boot keys, clear the TPM, remove pcrlock policy, or alter LUKS keyslots as part of `/etc`
recovery.

The tmpfs root means rolling back a generation restores the generated operating-system view while
persistent `/persist` state remains. A newly created `/var/lib/nixos` from Stage 1 is harmless to an
older generation that still uses `/etc` as Userborn's backing location.

## Perlless assessment

The system already satisfies the central modern-stack prerequisites used by the pinned perlless
profile: systemd initrd, overlay `/etc`, Userborn, nixos-init, and the non-Perl configuration
generator setting. The profile itself is not imported and must not be enabled as part of this task;
its strict forbidden-dependency regex would still conflict with intentionally retained packages such
as AppArmor profiles, btrbk, xdg tooling, and development tooling. Continue that migration
independently.
