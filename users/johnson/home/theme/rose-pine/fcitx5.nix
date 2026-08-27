{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkForce mkIf;
  cfg = config.nixporn;
  inherit (cfg.colorschemes.rose-pine) slug;
  classicUiFile = (pkgs.formats.iniWithGlobalSection { }).generate "fcitx5-classicui.conf" {
    globalSection = {
      Theme = slug;
      DarkTheme = slug;
      Font = "LXGW WenKai 16";
      MenuFont = "LXGW WenKai 12";
      TrayFont = "LXGW WenKai 12";
      UseDarkTheme = true;
      UseAccentColor = false;
    };
  };
in
{
  config = mkIf (cfg.colorscheme == "rose-pine" && cfg.fcitx5.enable && cfg.fcitx5.apply) {
    xdg.configFile."fcitx5/conf/classicui.conf" = mkForce {
      source = classicUiFile;
    };
  };
}
