{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.meta) getExe';
  inherit (lib.options) mkEnableOption;
  cfg = config.dot.networking.vpn;
  mullvad' = "${config.services.mullvad-vpn.package}/bin/mullvad";
  cat' = getExe' pkgs.coreutils "cat";
  mullvadAutoLoginScript = pkgs.writeShellScript "mullvad-auto-login.sh" ''
    set -e
    ${mullvad'} auto-connect set off
    case "$(${mullvad'} account get 2>/dev/null || true)" in
      ""|*"Not logged in"*)
        ${mullvad'} account login "$(${cat'} ${config.sops.secrets.mullvad_vpn_account_number.path})"
        ;;
    esac
    ${mullvad'} auto-connect set off
    ${mullvad'} disconnect --wait || true
  '';
in
{
  options.dot.networking.vpn = {
    enable = mkEnableOption "Mullvad VPN" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    dot.networking.tailscale = {
      acceptDns = false;
      acceptRoutes = false;
    };

    services.mullvad-vpn = {
      enable = true;
      enableExcludeWrapper = false;
      gui.enable = config.dot.gui.enable;
    };

    preservation.preserveAt."/persist".directories = mkIf config.dot.persistence.enable [
      "/etc/mullvad-vpn"
    ];

    sops.secrets.mullvad_vpn_account_number = {
      sopsFile = "${self}/secrets/services/mullvad.yaml";
      key = "mullvad_number";
    };

    systemd.services.mullvad-vpn-login = {
      description = "Log in to Mullvad VPN without connecting";
      after = [
        "mullvad-daemon.service"
        "sops-install-secrets.service"
      ];
      wants = [
        "mullvad-daemon.service"
        "sops-install-secrets.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = mullvadAutoLoginScript;
        Type = "oneshot";
        TimeoutStartSec = "2min";
      };
    };
  };
}
