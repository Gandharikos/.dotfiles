{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dot.virtual.podman;
  inherit (lib.modules) mkIf mkForce;
  inherit (lib.options) mkEnableOption;
in
{
  options.dot.virtual.podman = {
    enable = mkEnableOption "Podman";
  };
  config = mkIf cfg.enable {
    dot.virtual.docker.enable = mkForce false;
    environment.systemPackages = with pkgs; [
      podman-compose
      podman-desktop
    ];

    virtualisation = {
      # Registries to search for images on `podman pull`
      containers.registries.settings.registries.search.registries = [
        "docker.io"
        "quay.io"
        "ghcr.io"
        "gcr.io"
      ];

      podman = {
        enable = true;

        # Make Podman backwards compatible with Docker socket interface.
        # Certain interface elements will be different, but unless any
        # of said values are hardcoded, it should not pose a problem
        # for us.
        dockerCompat = true;
        dockerSocket.enable = true;

        defaultNetwork.settings.dns_enabled = true;

        # Enable Nvidia support for Podman if the Nvidia drivers are found
        # in the list of xserver.videoDrivers.
        enableNvidia = config.dot.device.gpu == "nvidia";

        # Prune images and containers periodically
        autoPrune = {
          enable = true;
          flags = [ "--all" ];
          dates = "weekly";
        };
      };

      containers.containersConf.settings = {
        engine.runtime = "crun";
      };
    };
  };
}
