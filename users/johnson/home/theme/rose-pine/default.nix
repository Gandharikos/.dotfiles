{
  inputs,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkDefault mkIf;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  cfg = config.nixporn.colorschemes.rose-pine;
  enable = config.nixporn.colorscheme == "rose-pine" && isLinux && osConfig.dot.gui.enable;
in
{
  imports = lib.dot.scanPaths ./.;

  config = mkIf enable {
    nixporn = {
      wallpaper = mkDefault inputs.wallpapers.rosepine.japan-mountain-pink.path;

      cursors.rose-pine = {
        baseColor = mkDefault cfg.palette.pine;
        outlineColor = mkDefault (if cfg.polarity == "light" then cfg.palette.text else cfg.palette.base);
      };
    };
  };
}
