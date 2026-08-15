{
  config,
  lib,
  ...
}:
let
  inherit (config) dot;
  inherit (config.dot.device) type;
  inherit (lib.modules) mkForce mkMerge mkIf;
  isMobile = type == "mobile" || type == "laptop";
  isHost = type == "desktop" || type == "workstation";
  isVirtual = type == "vm" || type == "wsl";
  isServer = type == "server";
in
{
  config = mkMerge [
    # { time.hardwareClockInLocalTime = true; }
    (mkIf isServer {
      time.timeZone = mkForce "UTC";
    })
    (mkIf isVirtual {
      # use the host's time
      time.timeZone = mkForce null;
    })
    (mkIf isHost {
      services = {
        chrony = {
          enable = true;
          autotrimThreshold = 10;
        };
        ntp.enable = mkForce false;
        timesyncd.enable = mkForce false;
      };

      networking.timeServers = [
        "0.cn.pool.ntp.org"
        "1.cn.pool.ntp.org"
        "2.cn.pool.ntp.org"
        "3.cn.pool.ntp.org"
        "0.alsa.pool.ntp.org"
        "1.alsa.pool.ntp.org"
        "2.alsa.pool.ntp.org"
        "3.alsa.pool.ntp.org"
        "0.pool.ntp.org"
        "1.pool.ntp.org"
        "2.pool.ntp.org"
        "3.pool.ntp.org"
      ];
    })
    (mkIf isMobile {
      # localtimed is deprecated, replaced by automatic-timezoned
      services = {
        automatic-timezoned.enable = true;
        geoclue2 = {
          enable = true;
          enableCDMA = false;
          enable3G = false;
          enableModemGPS = false;
          enableNmea = false;
          enableWifi = true;
          # Use default geoclue provider
          submitData = !dot.security.enable;
          appConfig.automatic-timezoned = {
            isAllowed = true;
            isSystem = true;
          };
        };
      };
      location.provider = "geoclue2";
      # GeoClue's Wi-Fi source requires wpa_supplicant, while NetworkManager uses iwd.
      # Keep city-level timezone detection working through BeaconDB's IP source.
      environment.etc."geoclue/conf.d/10-ip-source.conf".text = ''
        [ip]
        enable=true
        method=ichnaea
      '';
      # Prevent "Failed to open /etc/geoclue/conf.d/:" errors
      systemd.tmpfiles.rules = [
        "d /etc/geoclue/conf.d 0755 root root"
      ];
    })
  ];
}
