{
  config,
  inputs,
  lib,
  pkgs,
  _class,
  ...
}:
let
  inherit (lib.modules) mkForce mkIf;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  # Check names before types to avoid fetching excluded inputs.
  flakeInputs = lib.filterAttrs (
    name: value:
    name != "self" && !(builtins.elem name config.dot.nix.excludedInputs) && lib.isType "flake" value
  ) inputs;
  sudoers = if (_class == "nixos") then "@wheel" else "@admin";
in
{
  options.dot.nix.excludedInputs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "wallpapers" ];
    description = ''
      Flake input names to exclude from automatic registry and NIX_PATH entries.
      Platform modules and profiles can append exclusions. This does not prevent
      other modules from referencing these inputs. The nixpkgs registry entry
      remains pinned independently.
    '';
  };

  # Auto upgrade nix package and the daemon service.
  # services.nix-daemon.enable = true;
  # Use this instead of services.nix-daemon.enable if you
  # don't wan't the daemon service to be managed for you.
  # nix.useDaemon = true;
  config.nix = {
    registry = (lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs) // {
      # https://github.com/NixOS/nixpkgs/pull/388090
      nixpkgs = mkForce { flake = inputs.nixpkgs; };
    };
    nixPath =
      if _class == "nixos" then
        lib.attrValues (lib.mapAttrs (name: flake: "${name}=flake:${flake.outPath}") flakeInputs)
      else
        mkForce (lib.mapAttrs (_: flake: flake.outPath) flakeInputs);

    # automatically optimise /nix/store/  by removing hard links
    optimise.automatic = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
    # remove nix-channel related tools & configs, we use flakes instead.
    channel.enable = false;
    settings = {
      # these are the bare minimum settings required to get my nixos config working
      experimental-features = [
        # enables flakes, needed for this config
        "flakes"

        # enables the nix3 commands, a requirement for flakes
        "nix-command"

        # enables cgroups
        "cgroups"
      ];
      # users or groups that are allowed ot do anything with the Nix daemon
      allowed-users = [ sudoers ];
      # users or groups that are allowed to manage the nix store
      trusted-users = [ sudoers ];

      # we don't want to track the registry, but we do want to allow the useage
      # of the `flake:` references, so we need to enable use-registries
      use-registries = true;
      flake-registry = "";

      # let the system decide the number of max jobs
      max-jobs = "auto";

      # automatically optimise symlink
      auto-optimise-store = true;

      # allow building from source if a substituter is missing the requested nar
      fallback = true;

      # build inside sandboxed environments
      # we only enable this on linux because it servirly breaks on darwin
      sandbox = isLinux;

      # supported system features
      system-features = [
        "nixos-test"
        "kvm"
        "recursive-nix"
        "big-parallel"
      ];

      # continue building derivations even if one fails
      # this is important for keeping a nice cache of derivations, usually because I walk away
      # from my PC when building and it would be annoying to deal with nothing saved
      keep-going = true;

      # show more log lines for failed builds, as this happens alot and is useful
      log-lines = 30;

      # it's annoying to see the warning when running `nixos-rebuild switch`
      warn-dirty = false;

      # whether to accept nix configuration from a flake without prompting
      # littrally a CVE waiting to happen <https://x.com/puckipedia/status/1693927716326703441>
      accept-flake-config = false;

      # It's nice to have more http downloads when setting up
      http-connections = 50;

      # https://github.com/NixOS/nix/issues/11728
      download-buffer-size = 1073741824; # 1GB

      # this defaults to true, however it slows down evaluation so maybe we should disable it
      # some day, but we do need it for catppuccin/nix so maybe not too soon
      allow-import-from-derivation = true;

      # for direnv GC roots
      keep-derivations = true;
      keep-outputs = true;

      # use xdg base directories for all the nix things
      # Get Nix (2.14+) itself to respect XDG. I.e.
      # ~/.nix-defexpr -> $XDG_DATA_HOME/nix/defexpr
      # ~/.nix-profile -> $XDG_DATA_HOME/nix/profile
      # ~/.nix-channels -> $XDG_DATA_HOME/nix/channels
      use-xdg-base-directories = true;

      # Enable cgroups for more robust process isolation and resource management during builds
      use-cgroups = mkIf isLinux true;
    };
  };
}
