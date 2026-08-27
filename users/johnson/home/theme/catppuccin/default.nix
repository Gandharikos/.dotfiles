{
  inputs,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf mkMerge;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  cfg = config.nixporn.colorschemes.catppuccin;
  guiLinux = osConfig.dot.gui.enable && isLinux;
in
{
  imports = lib.dot.scanPaths ./.;

  config = mkIf (config.nixporn.colorscheme == "catppuccin") (mkMerge [
    {
      home.sessionVariables = {
        COLORSCHEME_FLAVOR = cfg.flavor;
        COLORSCHEME_ACCENT = cfg.accent;
      };
    }

    (mkIf guiLinux {
      nixporn = {
        avatar = lib.mkDefault osConfig.nixporn.avatar;
        wallpaper = lib.mkDefault inputs.wallpapers.catppuccin.anime-japan.path;
      };
    })
  ]);
}
