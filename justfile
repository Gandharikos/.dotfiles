set shell := ["bash", "-c"]
export NIX_CONFIG := "experimental-features = nix-command flakes"

flake := env('FLAKE', justfile_directory())
user := `whoami`
rebuild := if os() == "macos" { "sudo darwin-rebuild" } else { "nixos-rebuild" }
system-args := if os() == "macos" { "" } else { "--elevate run0 --no-reexec" }
libvirt-uri := "qemu:///system"
windows-domain := "windows11"

[private]
default:
    @just --list --unsorted

# ------------------------------------------------------------------------------
# rebuild
# ------------------------------------------------------------------------------

[group('rebuild')]
[no-exit-message]
[private]
builder goal host=`hostname -s` *args:
    {{ rebuild }} {{ goal }} \
      --flake {{ flake }}#{{ host }} \
      {{ system-args }} \
      {{ args }}

[group('rebuild')]
[no-exit-message]
switch host=`hostname -s` *args: (builder "switch" host args)

[group('rebuild')]
[no-exit-message]
boot host=`hostname -s` *args: (builder "boot" host args)

[group('rebuild')]
[no-exit-message]
test host=`hostname -s` *args: (builder "test" host args)

[group('rebuild')]
[no-exit-message]
vm host="mimir" *args:
    nix build path:{{ flake }}#nixosConfigurations.{{ host }}.config.system.build.vm {{ args }}
    ./result/bin/run-{{ host }}-vm

[group('rebuild')]
[no-exit-message]
rollback *args:
    {{ rebuild }} switch --rollback \
        {{ system-args }} \
        {{ args }}

[group('rebuild')]
[no-exit-message]
deploy host action="switch" *args:
    #!/usr/bin/env bash
    set -euo pipefail

    build_host_args=()
    if [[ -n "${BUILD_HOST:-}" ]]; then
        build_host_args=(--build-host "$BUILD_HOST")
    fi
    before="$(ssh -q {{ host }} 'readlink -e /run/current-system || true')"

    nixos-rebuild "{{ action }}" \
        --flake {{ flake }}#{{ host }} \
        --target-host {{ host }} \
        "${build_host_args[@]}" \
        --use-substitutes \
        --use-remote-sudo \
        --log-format internal-json \
        {{ args }}

    after="$(ssh -q {{ host }} 'readlink -e /run/current-system || true')"
    if [[ -n "$before" && -n "$after" && "$before" != "$after" ]]; then
        echo
        echo "===== {{ host }} ({{ action }}) ====="
        ssh {{ host }} TERM=xterm-256color nix store diff-closures "$before" "$after" || true
    fi

# ------------------------------------------------------------------------------
# virtualization
# ------------------------------------------------------------------------------

[group('virtualization')]
[no-exit-message]
windows:
    #!/usr/bin/env bash
    set -euo pipefail

    uri="{{ libvirt-uri }}"
    domain="{{ windows-domain }}"
    state="$(virsh --connect "$uri" domstate "$domain")"

    case "$state" in
      running)
        ;;
      paused)
        virsh --connect "$uri" resume "$domain"
        ;;
      "shut off" | crashed)
        virsh --connect "$uri" start "$domain"
        ;;
      *)
        echo "Cannot open $domain while it is $state" >&2
        exit 1
        ;;
    esac

    exec virt-viewer \
      --connect "$uri" \
      --attach \
      --reconnect \
      --full-screen \
      --auto-resize=always \
      --hotkeys=toggle-fullscreen=shift+f11,release-cursor=ctrl+alt \
      --domain-name \
      "$domain"

[group('virtualization')]
[no-exit-message]
windows-stop timeout="60":
    #!/usr/bin/env bash
    set -euo pipefail

    uri="{{ libvirt-uri }}"
    domain="{{ windows-domain }}"
    timeout="{{ timeout }}"
    state="$(virsh --connect "$uri" domstate "$domain")"

    if [[ "$state" == "shut off" ]]; then
      echo "$domain is already shut off"
      exit 0
    fi

    if [[ "$state" == "paused" ]]; then
      virsh --connect "$uri" resume "$domain"
    elif [[ "$state" != "running" ]]; then
      echo "Cannot gracefully stop $domain while it is $state" >&2
      exit 1
    fi

    if virsh --connect "$uri" qemu-agent-command "$domain" '{"execute":"guest-ping"}' >/dev/null 2>&1; then
      virsh --connect "$uri" shutdown "$domain" --mode agent
    else
      virsh --connect "$uri" shutdown "$domain" --mode acpi
    fi

    for ((seconds = 0; seconds < timeout; seconds++)); do
      if [[ "$(virsh --connect "$uri" domstate "$domain")" == "shut off" ]]; then
        echo "$domain shut down cleanly"
        exit 0
      fi
      sleep 1
    done

    echo "$domain did not shut down within ${timeout}s; it was not force-stopped" >&2
    exit 1

[group('virtualization')]
[no-exit-message]
windows-status:
    #!/usr/bin/env bash
    set -euo pipefail

    uri="{{ libvirt-uri }}"
    domain="{{ windows-domain }}"
    state="$(virsh --connect "$uri" domstate "$domain")"

    virsh --connect "$uri" dominfo "$domain"
    echo
    virsh --connect "$uri" domblkinfo "$domain" --all --human

    if [[ "$state" == "running" ]]; then
      echo
      virsh --connect "$uri" domifaddr "$domain" --source lease --full
    fi

# ------------------------------------------------------------------------------
# install
# ------------------------------------------------------------------------------

[group('install')]
[no-exit-message]
install host target *args:
    nixos-anywhere \
        --flake {{ flake }}#{{ host }} \
        --copy-host-keys \
        --build-on auto \
        {{ args }} \
        {{ target }}

[group('install')]
[no-exit-message]
disko host *args:
    sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko/latest#disko-install -- \
        --write-efi-boot-entries \
        --flake {{ flake }}#{{ host }} \
        {{ args }}

# ------------------------------------------------------------------------------
# dev
# ------------------------------------------------------------------------------

[group('dev')]
[no-exit-message]
check *args:
    #!/usr/bin/env bash
    set -euo pipefail

    nix flake check --option allow-import-from-derivation false {{ args }} {{ flake }}

    if command -v statix >/dev/null 2>&1; then
        statix check .
    fi

[group('dev')]
[no-exit-message]
update *inputs:
    nix flake update {{ inputs }} --flake {{ flake }}

[group('dev')]
[no-exit-message]
history:
    nix profile history --profile /nix/var/nix/profiles/system

[group('dev')]
[no-exit-message]
repl:
    nix repl {{ flake }}

[group('dev')]
[no-exit-message]
repl-host host=`hostname -s`:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "{{ os() }}" == "macos" ]]; then
        nix repl {{ flake }}#darwinConfigurations.{{ host }}
    else
        nix repl {{ flake }}#nixosConfigurations.{{ host }}
    fi

[group('dev')]
[no-exit-message]
dev name="default":
    nix develop {{ flake }}#{{ name }}

[group('dev')]
[no-exit-message]
fmt:
    nix fmt

[group('dev')]
rm program:
    rm -rf "$HOME/.config/{{ program }}"

[group('dev')]
cfg program:
    just rm {{ program }}
    rsync -avz --copy-links config/{{ program }}/ "$HOME/.config/{{ program }}/"

[group('dev')]
add program:
    rm -rf config/{{ program }}/
    mv "$HOME/.config/{{ program }}" config/

# ------------------------------------------------------------------------------
# secret
# ------------------------------------------------------------------------------

[group('secret')]
bootstrap host=`hostname -s`:
    #!/usr/bin/env bash
    mkdir -p ~/.ssh
    sops -d --extract '["data"]' secrets/{{ user }}/core/id_ed25519.yaml > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519

    sudo mkdir -p /etc/ssh
    sops -d --extract '["data"]' secrets/{{ user }}/core/{{ host }}.yaml | sudo tee /etc/ssh/ssh_host_ed25519_key > /dev/null
    sudo chmod 600 /etc/ssh/ssh_host_ed25519_key
    sudo cp secrets/{{ user }}/core/{{ host }}.pub /etc/ssh/ssh_host_ed25519_key.pub
    sudo chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

[group('secret')]
bootstrap-remote host ip:
    #!/usr/bin/env bash
    set -euo pipefail

    tmp_dir="$(mktemp -d /tmp/keys-{{ host }}.XXXXXX)"
    trap 'rm -rf "$tmp_dir"' EXIT

    sops -d --extract '["data"]' secrets/{{ user }}/core/id_ed25519.yaml > "$tmp_dir/id_ed25519"
    cp secrets/{{ user }}/core/id_ed25519.pub "$tmp_dir/id_ed25519.pub"
    sops -d --extract '["data"]' secrets/{{ user }}/core/{{ host }}.yaml > "$tmp_dir/ssh_host_ed25519_key"
    cp secrets/{{ user }}/core/{{ host }}.pub "$tmp_dir/ssh_host_ed25519_key.pub"

    chmod 600 "$tmp_dir/id_ed25519" "$tmp_dir/ssh_host_ed25519_key"

    ssh {{ user }}@{{ ip }} "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    scp "$tmp_dir/id_ed25519" "$tmp_dir/id_ed25519.pub" {{ user }}@{{ ip }}:~/.ssh/
    scp "$tmp_dir/ssh_host_ed25519_key" "$tmp_dir/ssh_host_ed25519_key.pub" {{ user }}@{{ ip }}:~/

    ssh -t {{ user }}@{{ ip }} "sudo install -d -m 755 /etc/ssh && \
      sudo install -m 600 ~/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key && \
      sudo install -m 644 ~/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub && \
      rm ~/ssh_host_ed25519_key*"

    ssh -t {{ user }}@{{ ip }} "sudo mkdir -p /nix/var/nix/profiles/per-user/{{ user }} && \
      sudo chown {{ user }}:users /nix/var/nix/profiles/per-user/{{ user }} && \
      sudo chmod 755 /nix/var/nix/profiles/per-user/{{ user }}"

    ssh {{ user }}@{{ ip }} "chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/id_ed25519.pub"

# ------------------------------------------------------------------------------
# utils
# ------------------------------------------------------------------------------

alias fix := repair

[group('utils')]
[no-exit-message]
clean:
    sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d

[group('utils')]
[no-exit-message]
gc:
    sudo nix-collect-garbage --delete-older-than 7d
    sudo nix store optimise

[group('utils')]
[no-exit-message]
gcroot:
    ls -al /nix/var/nix/gcroots/auto/

[group('utils')]
[no-exit-message]
reload:
    nix-direnv-reload

[group('utils')]
[no-exit-message]
verify:
    sudo nix store verify --all

[group('utils')]
[no-exit-message]
repair *paths:
    sudo nix store repair {{ paths }}
