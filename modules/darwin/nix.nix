{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.fast-nix-gc.darwinModules.default ];

  dot.nix.excludedInputs = [
    "asus-dialpad-driver"
    "dedsec-grub-theme"
    "disko"
    "dms"
    "hardware"
    "hypr-dynamic-cursors"
    "hypridle"
    "hyprland"
    "lanzaboote"
    "microvm"
    "niri"
    "nix-gaming"
    "nix-topology"
    "nixos-anywhere"
    "nixpak"
    "noctalia"
    "noctalia-official-plugins"
    "noctalia-qs"
    "nvidia-patch"
    "preservation"
    "simple-nixos-mailserver"
    "vicinae"
    "vicinae-extensions"
    "wallpapers"
    "wsl"
  ];

  nix = {
    gc.automatic = lib.mkForce false;
    optimise.automatic = lib.mkForce false;

    # we add more platforms here because of the limited number of darwin
    # maintainers that exist, thus meaning less working packages for darwin.
    settings.extra-platforms = [
      "aarch64-darwin"
      "x86-64-darwin"
    ];
  };

  services = {
    fast-nix-gc = {
      enable = true;
      package = inputs.fast-nix-gc.packages.${pkgs.stdenv.hostPlatform.system}.default;
      automatic = true;
      startCalendarInterval = [
        {
          Hour = 3;
          Minute = 15;
        }
      ];
      deleteOlderThan = "7d";
    };

    fast-nix-optimise = {
      enable = true;
      automatic = true;
      startCalendarInterval = [
        {
          Hour = 4;
          Minute = 0;
        }
      ];
    };
  };
}
