{
  inputs,
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (lib.meta) getExe';
  inherit (lib.dot) uwsmAppArgs;
  cfg = config.my.gui.apps.helium;
  enable = osConfig.dot.gui.enable && cfg.enable;
  heliumPkg = pkgs.helium;
in
{
  imports = [ inputs.helium-browser.homeModules.default ];

  options.my.gui.apps.helium = {
    enable = mkEnableOption "Helium browser" // {
      default = config.my.gui.browser.default == "helium";
    };
  };

  config = mkIf enable {
    programs.helium = {
      enable = true;
      package = heliumPkg;
      flags = [
        "--ozone-platform-hint=auto"
        "--disable-accelerated-video-decode"
        "--disable-features=VaapiVideoDecoder,VaapiOnNvidiaGPUs,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL"
      ];
      policies = {
        BrowserSignin = 0;
        PasswordManagerEnabled = false;
        SyncDisabled = true;
      };
    };

    my.gui.browser = mkIf (config.my.gui.browser.default == "helium") {
      desktopId = "helium.desktop";
      command =
        if osConfig.dot.gui.desktop.uwsm.enable then
          uwsmAppArgs pkgs (getExe' heliumPkg "helium") [ ]
        else
          [ (getExe' heliumPkg "helium") ];
    };
  };
}
