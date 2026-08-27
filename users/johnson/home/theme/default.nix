{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.dot) scanPaths;
  inherit (lib.modules) mkIf;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  imports = scanPaths ./.;

  config = mkIf (isLinux && osConfig.dot.gui.enable) {
    home.pointerCursor = {
      enable = true;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };
  };
}
