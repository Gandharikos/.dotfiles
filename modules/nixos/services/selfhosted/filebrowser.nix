{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dot.selfhosted.services.filebrowser;
  kanidm = config.dot.selfhosted.services.kanidm;
  oidcEnabled = kanidm.enable;
  proxyBackend =
    if oidcEnabled then
      {
        inherit (cfg) host scheme;
        port = cfg.authProxy.port;
      }
    else
      cfg;
  dataDirGroup = if oidcEnabled then "kanidm" else "filebrowser";
  oauth2SecretDir = "/var/lib/kanidm/oauth2/filebrowser";
  oauth2ClientSecretFile = "${oauth2SecretDir}/client-secret";
  oauth2CookieSecretFile = "${oauth2SecretDir}/cookie-secret";
  oauth2EnvFile = "${oauth2SecretDir}/env";
  inherit (lib) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) port str;
in
{
  options.dot.selfhosted.services.filebrowser =
    lib.dot.mkSelfhostedServiceOptions {
      inherit config;
      name = "filebrowser";
      displayName = "FileBrowser";
      subdomain = "files";
      defaultPort = 8086;
      defaultEnable = false;
    }
    // {
      dataDir = mkOption {
        type = str;
        default = "/var/lib/filebrowser";
        description = "FileBrowser persistent state directory.";
      };

      filesDir = mkOption {
        type = str;
        default = "${cfg.dataDir}/files";
        description = "Directory exposed through FileBrowser.";
      };

      authProxy.port = mkOption {
        type = port;
        default = 4186;
        description = "Local oauth2-proxy port used when Kanidm protects FileBrowser.";
      };
    };

  config = mkIf cfg.enable {
    dot.selfhosted = {
      proxyBackends.filebrowser = {
        inherit (cfg)
          hostName
          localHostAlias
          ;
        inherit (proxyBackend) host port scheme;
      };
      services.gatus.endpoints = [ (lib.dot.mkGatusEndpoint "filebrowser" cfg) ];
      backups.paths = [ cfg.dataDir ];
    };

    services.kanidm.provision = mkIf oidcEnabled {
      groups.filebrowser-users.members = [ "johnson" ];
      persons.johnson.groups = [ "filebrowser-users" ];
      systems.oauth2.filebrowser = {
        displayName = "FileBrowser";
        originLanding = "https://${cfg.hostName}/";
        originUrl = "https://${cfg.hostName}/oauth2/callback";
        basicSecretFile = oauth2ClientSecretFile;
        preferShortUsername = true;
        scopeMaps.filebrowser-users = [
          "openid"
          "email"
          "profile"
        ];
      };
    };

    services.filebrowser = {
      enable = true;
      settings = {
        address = cfg.host;
        inherit (cfg) port;
        root = cfg.filesDir;
        database = "${cfg.dataDir}/db/database.db";
        noauth = oidcEnabled;
        branding = {
          name = "Files";
          disableExternal = true;
        };
      };
    };

    systemd.tmpfiles.settings.selfhosted-filebrowser = {
      ${cfg.dataDir}.d = {
        user = "filebrowser";
        group = dataDirGroup;
        mode = "0750";
      };
      ${cfg.filesDir}.d = {
        user = "filebrowser";
        group = "filebrowser";
        mode = "0750";
      };
      ${oauth2SecretDir}.d = {
        user = "root";
        group = "kanidm";
        mode = "0750";
      };
    };

    systemd.services = {
      filebrowser = {
        preStart = ''
          ${lib.getExe' pkgs.coreutils "mkdir"} -p ${cfg.filesDir}
          ${lib.getExe' pkgs.coreutils "chmod"} 0750 ${cfg.filesDir}
        '';
        serviceConfig.WorkingDirectory = lib.mkForce cfg.dataDir;
      };

      kanidm = mkIf oidcEnabled {
        after = [ "filebrowser-oauth2-secrets.service" ];
        requires = [ "filebrowser-oauth2-secrets.service" ];
      };

      filebrowser-oauth2-secrets = mkIf oidcEnabled {
        description = "Generate FileBrowser OAuth2 secrets";
        before = [
          "kanidm.service"
          "oauth2-proxy-filebrowser.service"
        ];
        requiredBy = [
          "kanidm.service"
          "oauth2-proxy-filebrowser.service"
        ];
        serviceConfig.Type = "oneshot";
        script = ''
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o filebrowser -g ${dataDirGroup} ${cfg.dataDir}
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o root -g kanidm ${oauth2SecretDir}

          if [ ! -s ${oauth2ClientSecretFile} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -base64 48 | ${lib.getExe' pkgs.coreutils "tr"} -d '\n' > ${oauth2ClientSecretFile}
          fi

          cookie_secret="$(${lib.getExe' pkgs.coreutils "cat"} ${oauth2CookieSecretFile} 2>/dev/null || true)"
          if [ ''${#cookie_secret} -ne 16 ] && [ ''${#cookie_secret} -ne 24 ] && [ ''${#cookie_secret} -ne 32 ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -hex 16 > ${oauth2CookieSecretFile}
          fi

          ${lib.getExe' pkgs.coreutils "chown"} root:kanidm ${oauth2ClientSecretFile} ${oauth2CookieSecretFile}
          ${lib.getExe' pkgs.coreutils "chmod"} 0440 ${oauth2ClientSecretFile} ${oauth2CookieSecretFile}

          {
            printf 'OAUTH2_PROXY_CLIENT_SECRET=%s\n' "$(${lib.getExe' pkgs.coreutils "cat"} ${oauth2ClientSecretFile})"
            printf 'OAUTH2_PROXY_COOKIE_SECRET=%s\n' "$(${lib.getExe' pkgs.coreutils "cat"} ${oauth2CookieSecretFile})"
          } > ${oauth2EnvFile}

          ${lib.getExe' pkgs.coreutils "chown"} root:root ${oauth2EnvFile}
          ${lib.getExe' pkgs.coreutils "chmod"} 0400 ${oauth2EnvFile}
        '';
      };

      oauth2-proxy-filebrowser = mkIf oidcEnabled {
        description = "oauth2-proxy for FileBrowser";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "kanidm.service"
          "filebrowser.service"
          "filebrowser-oauth2-secrets.service"
        ];
        requires = [
          "kanidm.service"
          "filebrowser.service"
          "filebrowser-oauth2-secrets.service"
        ];
        script = ''
          exec ${getExe pkgs.oauth2-proxy} \
            --provider=oidc \
            --oidc-issuer-url=https://${kanidm.hostName}/oauth2/openid/filebrowser \
            --client-id=filebrowser \
            --http-address=http://${cfg.host}:${toString cfg.authProxy.port} \
            --redirect-url=https://${cfg.hostName}/oauth2/callback \
            --upstream=http://${cfg.host}:${toString cfg.port}/ \
            --scope="openid email profile" \
            --email-domain="*" \
            --reverse-proxy=true \
            --cookie-secure=true \
            --cookie-name=_filebrowser_oauth2_proxy \
            --cookie-domain=${cfg.hostName} \
            --pass-basic-auth=true \
            --pass-host-header=true \
            --set-xauthrequest=true \
            --skip-provider-button=true \
            --code-challenge-method=S256 \
            --oidc-email-claim=preferred_username \
            --prefer-email-to-user=true
        '';
        serviceConfig = {
          DynamicUser = true;
          EnvironmentFile = oauth2EnvFile;
          Restart = "always";
          RestartSec = "10s";
        };
      };
    };
  };
}
