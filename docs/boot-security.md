# Boot security

This document describes the boot-security architecture for the NixOS host `ymir`. It intentionally
keeps TPM measured boot separate from LUKS authentication.

## Architecture

```text
UEFI Secure Boot
  -> signed systemd-boot and Lanzaboote UKI
  -> TPM PCR measurements and systemd-pcrlock policy

YubiKey possession
  + FIDO2 client PIN
  + physical touch/user presence
  -> LUKS2 root unlock
```

The TPM is **not** enrolled as an alternate LUKS unlock mechanism. Do not add `tpm2-device=auto`, a
`systemd-tpm2` LUKS token, or `boot.lanzaboote.measuredBoot.autoCryptenroll` unless TPM-based root
unlock is explicitly desired in the future.

## Root LUKS device and authentication

Disko declares the root container using the stable GPT partlabel:

```text
/dev/disk/by-partlabel/disk-main-luks
```

On the audited installation, its stable LUKS UUID path is:

```text
/dev/disk/by-uuid/a013979e-48a4-4c14-890c-443587efa911
```

Resolve these links and compare them with the backing device of `/dev/mapper/crypted`; do not assume
an NVMe partition number.

The audited container is LUKS2. Keyslot 1 is referenced by a `systemd-fido2` token whose metadata
requires both the FIDO2 client PIN and user presence. The NixOS initrd uses systemd and Disko emits:

```nix
crypttabExtraOpts = [
  "fido2-device=auto"
  "token-timeout=10"
];
```

Keyslot 0 is active without token metadata and is consistent with the passphrase created during the
original Disko installation. Metadata alone cannot prove that the recovery passphrase is available
or independent. Test it interactively before any destructive keyslot, token, Secure Boot, or TPM
policy operation:

```bash
sudo cryptsetup open \
  --test-passphrase \
  --key-slot 0 \
  /dev/disk/by-uuid/a013979e-48a4-4c14-890c-443587efa911
```

Enter the passphrase only at the terminal prompt. Never place it in a command argument, shell
history, log, or repository file. This test does not open another mapping or modify the LUKS header.

Never remove the working FIDO2 slot before an additive replacement has been enrolled and tested.

## Secure Boot and Lanzaboote

`modules/nixos/boot/secureBoot.nix` imports the pinned Lanzaboote module, disables the competing
NixOS systemd-boot installer, signs UKIs with the existing sbctl bundle in `/var/lib/sbctl`, and
leaves firmware key enrollment manual. Existing PK, KEK, and db keys must not be regenerated or
replaced without a specific recovery plan.

The host enables measured boot with a limit of eight boot generations. Eight is the maximum accepted
by the pinned Lanzaboote/systemd-pcrlock integration.

The initial PCR policy is:

- **PCR 0 — platform/firmware code:** detects changes in the firmware code measurement chain.
- **PCR 4 — boot-loader code:** covers systemd-boot and the Lanzaboote stub. Lanzaboote verifies the
  kernel, initrd, and command line embedded in the UKI, extending this trust through the boot
  artifact.
- **PCR 7 — Secure Boot policy:** reflects Secure Boot policy and signing-authority state.

PCRs 1, 2, and 3 are deliberately excluded because the pinned Lanzaboote documentation identifies
them as potentially firmware-sensitive.

## Persistent measured-boot state

`ymir` has a tmpfs root, but preservation bind-mounts all of `/var/lib` from the encrypted
`/persist` subvolume. This already persists both defaults used by the pinned Lanzaboote revision:

```text
/var/lib/pcrlock.d
/var/lib/systemd/pcrlock.json
```

The first path stores generated pcrlock components. The second stores the policy. `/var/lib/sbctl`
is covered by the same persistent `/var/lib` mount. Do not reduce this to a guessed single-file
persistence rule, and do not wipe any of these paths as routine cleanup.

## Build and runtime transition

Evaluate and build before changing the boot profile:

```bash
just check
nix build --no-link .#nixosConfigurations.ymir.config.system.build.toplevel
```

At audit time, generation 570 was booted while generation 583 was already the signed default. Since
the measured-boot configuration reduces the ESP limit to eight generations, first reboot and prove
the already-installed default generation works while generation 570 remains available as fallback.
Only after verifying normal FIDO2 unlock and the independent recovery credential should the new
configuration be installed to the boot profile:

```bash
just boot ymir
```

The Lanzaboote install hook predicts the supported generation measurements and creates or updates
the systemd-pcrlock policy. It does not enroll or modify any LUKS token when `autoCryptenroll` is
disabled. Review the command result and ESP space, then reboot manually.

A routine later `nixos-rebuild boot` updates the signed UKIs and authorized PCR policy variants for
the retained generations. It does not require FIDO2 re-enrollment.

## Verification

After reboot:

```bash
sudo bootctl status --no-pager
sudo sbctl status
sudo sbctl verify
sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported
systemd-analyze pcrs --no-pager
systemctl status systemd-pcrlock-make-policy.service --no-pager
sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock list-components --no-pager
sudo stat /var/lib/systemd/pcrlock.json /var/lib/pcrlock.d
```

Confirm that Secure Boot remains enabled, the booted artifact is a signed Lanzaboote UKI, PCRs 0, 4,
and 7 have values, and policy generation succeeded.

Test the security boundaries:

1. **Normal boot:** require the YubiKey, its FIDO2 PIN, and touch.
2. **No YubiKey:** verify root does not silently unlock; only the intentional recovery-passphrase
   path may succeed.
3. **Measured boot:** inspect the PCRs, pcrlock components, policy file metadata, and service
   status.
4. **Upgrade:** build and install a new generation, then verify policy update without LUKS token
   changes.
5. **Rollback:** retain and test a known-good entry among the eight supported generations.

## Recovery

### Root unlock recovery

Use the independently stored keyslot-0 passphrase. It must not depend on a YubiKey, TPM state,
Secure Boot keys, or files available only inside the encrypted machine. From trusted recovery media,
identify the container by UUID before opening it.

Test the passphrase before it is needed:

```bash
sudo cryptsetup open \
  --test-passphrase \
  --key-slot 0 \
  /dev/disk/by-uuid/a013979e-48a4-4c14-890c-443587efa911
```

Success normally produces no output and exits with status zero. This test neither creates a mapping
nor modifies the LUKS header. Enter the passphrase only at the interactive prompt.

### YubiKey unavailable or lost

The initrd waits up to ten seconds for the configured FIDO2 token. If the YubiKey is absent or FIDO2
unlock is cancelled, wait for the LUKS passphrase prompt and enter the independent keyslot-0
passphrase. This path does not depend on the YubiKey, TPM, PCR state, Secure Boot, or pcrlock
policy. The TPM cannot silently unlock this volume because no TPM2 LUKS token is enrolled.

After booting with the recovery passphrase, enroll a replacement YubiKey additively:

```bash
sudo systemd-cryptenroll \
  --fido2-device=auto \
  --fido2-with-client-pin=yes \
  --fido2-with-user-presence=yes \
  /dev/disk/by-uuid/a013979e-48a4-4c14-890c-443587efa911
```

Supply an existing LUKS credential only at the prompt, then enter the new YubiKey's FIDO2 PIN and
touch it when requested. List the enrollment types without displaying credential material:

```bash
sudo systemd-cryptenroll \
  /dev/disk/by-uuid/a013979e-48a4-4c14-890c-443587efa911
```

Reboot and prove that the replacement YubiKey completes PIN-and-touch root unlock. Re-test keyslot 0
as well. Do not remove the old FIDO2 slot until the replacement and recovery passphrase have both
been proven. Never assume a slot number after enrollment; identify the exact old and replacement
token-to-slot mapping before proposing a wipe.

If both the YubiKey and recovery passphrase are lost, the encrypted data cannot be recovered through
the TPM, Secure Boot, or measured boot. Restore from an independent backup or reinstall the system.

### Boot rollback

Select a known-good signed generation in the systemd-boot menu. Once booted, inspect the failed
policy unit and logs before making changes:

```bash
systemctl status systemd-pcrlock-make-policy.service --no-pager
journalctl -b -u systemd-pcrlock-make-policy.service --no-pager
```

The FIDO2 root credential is independent of pcrlock, so a pcrlock failure must not be “fixed” by
changing LUKS slots.

### Broken pcrlock policy

Removing a pcrlock policy deallocates TPM policy state and is destructive. Do not do it as cleanup.
First verify both the working FIDO2 credential and independent recovery passphrase, preserve a
bootable generation, and record the failure. If policy removal is actually required:

1. Temporarily set `boot.lanzaboote.measuredBoot.enable = false` and successfully install that boot
   configuration.
2. Run the pinned systemd recovery command:

   ```bash
   sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock remove-policy
   ```

3. Re-enable measured boot, build it, install it with `just boot ymir`, and reboot only after the
   install succeeds.

There is no TPM2 LUKS token to wipe or re-enroll in this architecture. Never run
`systemd-cryptenroll --wipe-slot=tpm2` against the root container unless a future audit first shows
that such a token intentionally exists and an explicit TPM-unlock migration is being performed.
