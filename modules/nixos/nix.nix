{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.fast-nix-gc.nixosModules.default ];

  dot.nix.excludedInputs = [
    "darwin"
    "nix-homebrew"
    "omniwm"
  ];

  nix = {
    gc.automatic = lib.mkForce false;
    optimise.automatic = lib.mkForce false;

    # NixOS schedules optimise jobs with systemd calendar strings.
    optimise.dates = [ "04:00" ];
  };

  services = {
    fast-nix-gc = {
      enable = true;
      package = inputs.fast-nix-gc.packages.${pkgs.stdenv.hostPlatform.system}.default;
      automatic = true;
      dates = "daily";
      deleteOlderThan = "7d";
      randomizedDelaySec = "45min";
    };

    fast-nix-optimise = {
      enable = true;
      automatic = true;
      dates = [ "04:00" ];
    };
  };
}
