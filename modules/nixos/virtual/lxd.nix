# Inspired by https://www.srid.ca/2012301.html
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.dot.virtual.lxd;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
in
{
  options.dot.virtual.lxd = {
    enable = mkEnableOption "Enable LXD" // {
      default = config.dot.virtual.enable;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "lxc-build-nixos-image" ''
        set -euo pipefail

        if [[ $# -ne 1 ]]; then
          echo "Usage: lxc-build-nixos-image <flake#host>" >&2
          exit 2
        fi

        flakeTarget="$1"
        metaImage="$(${lib.getExe pkgs.nixos-rebuild} build-image \
          --no-reexec \
          --no-link \
          --flake "$flakeTarget" \
          --image-variant lxc-metadata)"
        image="$(${lib.getExe pkgs.nixos-rebuild} build-image \
          --no-reexec \
          --no-link \
          --flake "$flakeTarget" \
          --image-variant lxc)"

        lxc image import --alias nixos "$metaImage" "$image"
      '')
    ];
  };
}
