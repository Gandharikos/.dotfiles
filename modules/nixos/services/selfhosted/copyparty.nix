{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dot.selfhosted.services.copyparty;
  kanidm = config.dot.selfhosted.services.kanidm;
  oidcEnabled = kanidm.enable;
  oauth2SecretDir = "/var/lib/kanidm/oauth2/copyparty";
  oauth2ClientSecretFile = "${oauth2SecretDir}/client-secret";
  oauth2CookieSecretFile = "${oauth2SecretDir}/cookie-secret";
  oauth2EnvFile = "${oauth2SecretDir}/env";
  configFile = pkgs.writeText "copyparty.conf" ''
    [global]
      i: ${cfg.host}
      p: ${toString cfg.port}
      no-crt
      name: Copyparty
      site: https://${cfg.hostName}/
      xff-hdr: cf-connecting-ip
      xff-src: 127.0.0.0/8
      rproxy: 1
      idp-h-usr: x-forwarded-user
      idp-login: https://${cfg.hostName}/oauth2/start?rd=/
      idp-store: 2
      idp-db: ${cfg.dataDir}/state/idp.db
      e2dsa
      e2ts

    [/]
      ${cfg.filesDir}
      accs:
        rwmda: johnson
      flags:
        hist: ${cfg.dataDir}/state
  '';
  inherit (lib) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) port str;
in
{
  options.dot.selfhosted.services.copyparty =
    lib.dot.mkSelfhostedServiceOptions {
      inherit config;
      name = "copyparty";
      displayName = "Copyparty";
      subdomain = "box";
      defaultPort = 3923;
      defaultEnable = false;
    }
    // {
      dataDir = mkOption {
        type = str;
        default = "/var/lib/copyparty";
        description = "Copyparty persistent state directory.";
      };

      filesDir = mkOption {
        type = str;
        default = "${cfg.dataDir}/files";
        description = "Directory exposed through Copyparty.";
      };

      authProxy.port = mkOption {
        type = port;
        default = 4186;
        description = "Local oauth2-proxy port used when Kanidm protects Copyparty.";
      };
    };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = oidcEnabled;
        message = "Copyparty requires Kanidm because it has no local account fallback in this deployment.";
      }
    ];

    dot.selfhosted = {
      proxyBackends.copyparty = {
        inherit (cfg) hostName localHostAlias;
        inherit (cfg.authProxy) port;
        inherit (cfg) host;
        scheme = "http";
      };
      services.gatus.endpoints = [
        {
          name = "copyparty";
          url = "http://${cfg.host}:${toString cfg.port}/";
          interval = "1m";
        }
      ];
      backups.paths = [ cfg.dataDir ];
    };

    services.kanidm.provision = {
      groups.copyparty-users.members = [ "johnson" ];
      persons.johnson.groups = [ "copyparty-users" ];
      systems.oauth2.copyparty = {
        displayName = "Copyparty";
        originLanding = "https://${cfg.hostName}/";
        originUrl = "https://${cfg.hostName}/oauth2/callback";
        basicSecretFile = oauth2ClientSecretFile;
        preferShortUsername = true;
        scopeMaps.copyparty-users = [
          "openid"
          "email"
          "profile"
        ];
      };
    };

    users = {
      groups.copyparty = { };
      users.copyparty = {
        isSystemUser = true;
        group = "copyparty";
        home = cfg.dataDir;
      };
    };

    systemd.tmpfiles.settings.selfhosted-copyparty = {
      ${cfg.dataDir}.d = {
        user = "copyparty";
        group = "copyparty";
        mode = "0750";
      };
      ${cfg.filesDir}.d = {
        user = "copyparty";
        group = "copyparty";
        mode = "0750";
      };
      "${cfg.dataDir}/state".d = {
        user = "copyparty";
        group = "copyparty";
        mode = "0750";
      };
      ${oauth2SecretDir}.d = {
        user = "root";
        group = "kanidm";
        mode = "0750";
      };
    };

    systemd.services = {
      copyparty = {
        description = "Copyparty file server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${getExe pkgs.copyparty} -c ${configFile}";
          User = "copyparty";
          Group = "copyparty";
          WorkingDirectory = cfg.dataDir;
          Environment = "XDG_CONFIG_HOME=${cfg.dataDir}/state";
          UMask = "0077";
          Restart = "always";
          RestartSec = "5s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.dataDir ];
        };
      };

      kanidm = {
        after = [ "copyparty-oauth2-secrets.service" ];
        requires = [ "copyparty-oauth2-secrets.service" ];
      };

      copyparty-oauth2-secrets = {
        description = "Generate Copyparty OAuth2 secrets";
        before = [
          "kanidm.service"
          "oauth2-proxy-copyparty.service"
        ];
        requiredBy = [
          "kanidm.service"
          "oauth2-proxy-copyparty.service"
        ];
        serviceConfig.Type = "oneshot";
        script = ''
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

      oauth2-proxy-copyparty = {
        description = "oauth2-proxy for Copyparty";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "kanidm.service"
          "copyparty.service"
          "copyparty-oauth2-secrets.service"
        ];
        requires = [
          "kanidm.service"
          "copyparty.service"
          "copyparty-oauth2-secrets.service"
        ];
        script = ''
          exec ${getExe pkgs.oauth2-proxy} \
            --provider=oidc \
            --oidc-issuer-url=https://${kanidm.hostName}/oauth2/openid/copyparty \
            --client-id=copyparty \
            --http-address=http://${cfg.host}:${toString cfg.authProxy.port} \
            --redirect-url=https://${cfg.hostName}/oauth2/callback \
            --upstream=http://${cfg.host}:${toString cfg.port}/ \
            --scope="openid email profile" \
            --email-domain="*" \
            --reverse-proxy=true \
            --trusted-proxy-ip=127.0.0.0/8 \
            --cookie-secure=true \
            --cookie-name=_copyparty_oauth2_proxy \
            --cookie-domain=${cfg.hostName} \
            --pass-host-header=true \
            --pass-user-headers=true \
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
