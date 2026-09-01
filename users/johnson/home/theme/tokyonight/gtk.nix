{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  cfg = config.nixporn.colorschemes.tokyonight;
  enable = config.nixporn.colorscheme == "tokyonight" && osConfig.dot.gui.enable && isLinux;
  # preferDark =
  #   if cfg.style == "day"
  #   then 0
  #   else 1;
in
{
  config = mkIf enable {
    # gkt's theme settings, generate files:
    #   1. ~/.gtkrc-2.0
    #   2. ~/.config/gtk-3.0/settings.ini
    #   3. ~/.config/gtk-4.0/settings.ini
    gtk = {
      enable = true;

      gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
      # cursor theme is set on cursor.nix

      font = {
        name = "SFProDisplay Nerd Font";
        size = 13;
      };

      iconTheme = {
        name = if cfg.style == "day" then "Papirus-Light" else "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };

      # gtk3.extraConfig.gtk-application-prefer-dark-theme = preferDark;
      # gtk4.extraConfig.gtk-application-prefer-dark-theme = preferDark;
    };
  };
}
