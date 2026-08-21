{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkForce;
  inherit (config.dot.gui) desktop;
  cfg = desktop.hyprland;
in
{
  options.dot.gui.desktop.hyprland = {
    enable = mkEnableOption "Enable Hyprland" // {
      default = desktop.wayland.enable && desktop.default == "hyprland";
      internal = true;
      readOnly = true;
    };
  };

  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
    };

    programs.uwsm.waylandCompositors.hyprland = {
      prettyName = "Hyprland";
      comment = "Hyprland compositor managed by UWSM";
      binPath = "/run/current-system/sw/bin/start-hyprland";
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

      # xdg-desktop-wlr (this section) is no longer needed, xdg-desktop-portal-hyprland
      # will (and should) override this one
      wlr.enable = mkForce false;
    };
  };
}
