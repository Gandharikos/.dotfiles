{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.brotab;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  chromiumManifest = builtins.toJSON {
    name = "brotab_mediator";
    description = "This mediator exposes interface over TCP to control browser's tabs";
    path = "${lib.getExe' pkgs.brotab "bt_mediator"}";
    type = "stdio";
    allowed_extensions = [ "brotab_mediator@example.org" ];
    allowed_origins = [
      "chrome-extension://mhpeahbikehnfkfnmopaigggliclhmnc/"
      "chrome-extension://knldjmfmopnpolahpmmgbagdohdnhkik/"
    ];
  };
in
{
  options.my.brotab = {
    enable = mkEnableOption "Brotab browser tab CLI";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.brotab ];

    home.file = mkIf pkgs.stdenv.isLinux {
      ".config/net.imput.helium/NativeMessagingHosts/brotab_mediator.json" = {
        force = true;
        text = chromiumManifest;
      };
      ".config/helium/NativeMessagingHosts/brotab_mediator.json" = {
        force = true;
        text = chromiumManifest;
      };
      ".config/chromium/NativeMessagingHosts/brotab_mediator.json" = {
        force = true;
        text = chromiumManifest;
      };
    };
  };
}
