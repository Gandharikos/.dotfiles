{
  inputs,
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.dot) scanPaths;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (config.my.gui) desktop;
  cfg = desktop.niri;
in
{
  imports = [ inputs.niri.homeModules.niri ] ++ scanPaths ./.;
  options.my.gui.desktop.niri = {
    enable = mkEnableOption "Enable Niri" // {
      default = osConfig.dot.gui.desktop.wayland.enable && osConfig.dot.gui.desktop.default == "niri";
      internal = true;
      readOnly = true;
    };
  };
  config = mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = pkgs.niri-unstable;
      settings = {
        gestures.hot-corners.enable = false;
        xwayland-satellite = {
          enable = true;
          path = lib.getExe pkgs.xwayland-satellite;
        };
        prefer-no-csd = true;
        hotkey-overlay = {
          skip-at-startup = true;
          hide-not-bound = false;
        };
      };
    };
  };
}
