{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (config.dot.gui) desktop;
  cfg = desktop.niri;
in
{
  options.dot.gui.desktop.niri = {
    enable = mkEnableOption "Enable Niri" // {
      default = desktop.wayland.enable && desktop.default == "niri";
      internal = true;
      readOnly = true;
    };
  };

  config = mkIf cfg.enable {
    programs.niri = {
      enable = true;
      package = pkgs.niri;
    };

    programs.uwsm.waylandCompositors.niri = {
      prettyName = "niri";
      comment = "Niri compositor managed by UWSM";
      binPath = "/run/current-system/sw/bin/niri";
      extraArgs = [ "--session" ];
    };
  };
}
