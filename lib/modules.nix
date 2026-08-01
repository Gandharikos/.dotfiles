{ lib, ... }:
let
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.options) mkEnableOption mkOption mkPackageOption;
  inherit (lib.types)
    bool
    enum
    port
    str
    ;

  mkProgram =
    pkgs: name: extraConfig:
    recursiveUpdate {
      enable = mkEnableOption "Enable ${name}";
      package = mkPackageOption pkgs name { };
    } extraConfig;

  mkGatusEndpoint = name: service: {
    inherit name;
    url = "${service.scheme}://${service.host}:${toString service.port}";
    interval = "1m";
    conditions = [ "[STATUS] < 500" ];
  };

  mkSelfhostedServiceOptions =
    {
      config,
      name,
      defaultPort,
      displayName ? name,
      subdomain ? displayName,
      defaultEnable ? config.dot.selfhosted.enable,
      scheme ? "http",
    }:
    let
      cfg = config.dot.selfhosted.services.${name};
    in
    {
      enable = mkEnableOption displayName // {
        default = defaultEnable;
      };
      host = mkOption {
        type = str;
        default = "127.0.0.1";
        description = "Address ${displayName} listens on.";
      };
      port = mkOption {
        type = port;
        default = defaultPort;
        description = "Port ${displayName} listens on.";
      };
      subdomain = mkOption {
        type = str;
        default = subdomain;
        description = "Local subdomain used by the reverse proxy.";
      };
      scheme = mkOption {
        type = enum [
          "http"
          "https"
        ];
        default = scheme;
        description = "Scheme used by the reverse proxy to reach ${displayName}.";
      };
      hostName = mkOption {
        type = str;
        default = "${cfg.subdomain}.${config.dot.selfhosted.domain}";
        description = "Local host name used by the reverse proxy.";
      };
      localHostAlias = mkOption {
        type = bool;
        default = true;
        description = "Whether this service host name is mapped to localhost on the host machine.";
      };
    };

  mkSelfhostedExportPackage =
    pkgs:
    pkgs.writeShellApplication {
      name = "selfhosted-export";
      runtimeInputs = with pkgs; [
        coreutils
        gnugrep
        gnutar
        postgresql
        systemd
        util-linux
        zstd
      ];
      text = ''
        if [ "$(id -u)" != 0 ]; then
          echo "selfhosted-export must be run as root" >&2
          exit 1
        fi

        output="''${1:-/var/backup/selfhosted/selfhosted-$(date -u +%Y%m%dT%H%M%SZ).tar.zst}"
        workdir="$(mktemp -d)"
        trap 'rm -rf "$workdir"' EXIT

        mkdir -p "$(dirname "$output")" "$workdir/postgresql" "$workdir/var/lib"

        if systemctl is-active --quiet postgresql.service; then
          runuser -u postgres -- pg_dumpall \
            | zstd -T0 -19 -o "$workdir/postgresql/all.sql.zst" > /dev/null
          runuser -u postgres -- pg_dumpall --globals-only | tee "$workdir/postgresql/globals.sql" > /dev/null
          runuser -u postgres -- psql -Atqc "SELECT datname FROM pg_database WHERE datname IN ('miniflux', 'vaultwarden', 'wakapi', 'linkwarden', 'roundcube', 'paperless', 'dawarich', 'immich')" \
            | while IFS= read -r database; do
                [ -n "$database" ] || continue
                runuser -u postgres -- pg_dump --format=custom "$database" \
                  | tee "$workdir/postgresql/$database.dump" > /dev/null
              done
        fi

        for directory in actual caddy dawarich fava filebrowser forgejo gatus immich kanidm linkwarden mailserver miniflux ntfy-sh paperless roundcube vaultwarden wakapi; do
          if [ -e "/var/lib/$directory" ]; then
            tar -C /var/lib -cpf "$workdir/var/lib/$directory.tar" "$directory"
          fi
        done

        tar -C "$workdir" --zstd -cpf "$output" .
        echo "$output"
      '';
    };

  mkSelfhostedTaildropPackage =
    pkgs: config:
    let
      cfg = config.dot.selfhosted;
      target = "${cfg.backups.taildrop.target}:";
    in
    pkgs.writeShellApplication {
      name = "selfhosted-taildrop-backup";
      runtimeInputs = with pkgs; [
        coreutils
        tailscale
      ];
      text = ''
        if [ "$(id -u)" != 0 ]; then
          echo "selfhosted-taildrop-backup must be run as root" >&2
          exit 1
        fi

        timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

        send_file() {
          local source="$1"
          local name="$2"

          if [ ! -s "$source" ]; then
            echo "missing or empty backup artifact: $source" >&2
            return 1
          fi

          tailscale file cp --update-interval=0 --name "$name" "$source" "${target}"
        }

        send_file "${cfg.backups.exportDir}/selfhosted-latest.tar.zst" "$timestamp-athena-selfhosted.tar.zst"
        send_file "${cfg.backups.postgresqlDumpFile}" "$timestamp-athena-postgresql.sql.zst"
      '';
    };
in
{
  inherit
    mkProgram
    mkGatusEndpoint
    mkSelfhostedExportPackage
    mkSelfhostedServiceOptions
    mkSelfhostedTaildropPackage
    ;
}
