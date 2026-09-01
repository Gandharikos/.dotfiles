{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.dot.selfhosted.services.outline;
  kanidm = config.dot.selfhosted.services.kanidm;
  mailserver = config.dot.selfhosted.services.mailserver;
  secretsFile = "${self}/secrets/services/kanidm.yaml";
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.modules) mkIf;
in
{
  options.dot.selfhosted.services.outline = lib.dot.mkSelfhostedServiceOptions {
    inherit config;
    name = "outline";
    subdomain = "wiki";
    defaultPort = 3002;
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = kanidm.enable;
        message = "Outline requires the self-hosted Kanidm service for authentication.";
      }
    ];

    dot.selfhosted = {
      proxyBackends.outline = {
        inherit (cfg)
          host
          hostName
          localHostAlias
          port
          scheme
          ;
      };
      services.gatus.endpoints = [
        {
          name = "outline";
          url = "${cfg.scheme}://${cfg.host}:${toString cfg.port}/_health";
          interval = "1m";
          conditions = [ "[STATUS] == 200" ];
        }
      ];
      backups.paths = [ "/var/lib/outline" ];
    };

    sops.secrets.kanidm-oauth2-outline = {
      sopsFile = secretsFile;
      key = "oauth2-outline";
      owner = "kanidm";
      group = "kanidm";
    };

    sops.templates.outline-kanidm-env = {
      owner = "outline";
      group = "outline";
      mode = "0400";
      content = ''
        OIDC_CLIENT_SECRET=${config.sops.placeholder.kanidm-oauth2-outline}
      '';
      restartUnits = [ "outline.service" ];
    };

    services.kanidm.provision = {
      groups.outline-users.members = [ "johnson" ];
      persons.johnson.groups = [ "outline-users" ];
      systems.oauth2.outline = {
        displayName = "Outline";
        originLanding = "https://${cfg.hostName}/";
        originUrl = "https://${cfg.hostName}/auth/oidc.callback";
        basicSecretFile = config.sops.secrets.kanidm-oauth2-outline.path;
        preferShortUsername = true;
        scopeMaps.outline-users = [
          "openid"
          "profile"
          "email"
        ];
      };
    };

    services.outline = {
      enable = true;
      inherit (cfg) port;
      publicUrl = "https://${cfg.hostName}";
      databaseUrl = "local";
      redisUrl = "local";
      storage = {
        storageType = "local";
        localRootDir = "/var/lib/outline/data";
        uploadMaxSize = 262144000;
      };
      defaultLanguage = "en_US";
      forceHttps = true;
      enableUpdateCheck = false;
      rateLimiter = {
        enable = true;
        requests = 1000;
        durationWindow = 60;
      };
    };

    systemd.services.outline = {
      after = [
        "kanidm.service"
        "sops-install-secrets.service"
      ];
      requires = [
        "kanidm.service"
        "sops-install-secrets.service"
      ];
      environment = {
        OIDC_CLIENT_ID = "outline";
        OIDC_ISSUER_URL = "https://${kanidm.hostName}/oauth2/openid/outline";
        OIDC_DISABLE_REDIRECT = "true";
        OIDC_USERNAME_CLAIM = "preferred_username";
        OIDC_DISPLAY_NAME = "Kanidm";
        OIDC_SCOPES = "openid profile email";
        PROXY_HEADERS_TRUSTED = "true";
      }
      // optionalAttrs mailserver.enable {
        SMTP_HOST = "127.0.0.1";
        SMTP_PORT = "25";
        SMTP_FROM_EMAIL = "noreply@${config.dot.selfhosted.domain}";
        SMTP_REPLY_EMAIL = config.dot.admin.email;
        SMTP_SECURE = "false";
        SMTP_DISABLE_STARTTLS = "true";
      };
      serviceConfig.EnvironmentFile = [ config.sops.templates.outline-kanidm-env.path ];
    };
  };
}
