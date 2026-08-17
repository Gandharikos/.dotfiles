{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dot.selfhosted.services.immich;
  kanidm = config.dot.selfhosted.services.kanidm;
  oidcEnabled = kanidm.enable;
  oauth2SecretDir = "/var/lib/kanidm/oauth2/immich";
  oauth2ClientSecretFile = "${oauth2SecretDir}/client-secret";
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types) path;
in
{
  options.dot.selfhosted.services.immich =
    lib.dot.mkSelfhostedServiceOptions {
      inherit config;
      name = "immich";
      displayName = "Immich";
      subdomain = "photo";
      defaultPort = 2283;
      defaultEnable = false;
    }
    // {
      mediaLocation = mkOption {
        type = path;
        default = "/var/lib/immich";
        description = "Directory used by Immich to store uploaded photos and videos.";
      };

      machineLearning.enable = mkEnableOption "Immich machine learning" // {
        default = false;
      };
    };

  config = mkIf cfg.enable {
    dot.selfhosted = {
      proxyBackends.immich = {
        inherit (cfg)
          host
          hostName
          localHostAlias
          port
          scheme
          ;
      };
      services.gatus.endpoints = [ (lib.dot.mkGatusEndpoint "immich" cfg) ];
      backups.paths = [ cfg.mediaLocation ];
    };

    services.kanidm.provision = mkIf oidcEnabled {
      groups.immich-users.members = [ config.dot.primaryUser ];
      persons.${config.dot.primaryUser}.groups = [ "immich-users" ];
      systems.oauth2.immich = {
        displayName = "Immich";
        originLanding = "https://${cfg.hostName}/auth/login?autoLaunch=1";
        originUrl = [
          "https://${cfg.hostName}/auth/login"
          "https://${cfg.hostName}/user-settings"
          "https://${cfg.hostName}/api/oauth/mobile-redirect"
        ];
        basicSecretFile = oauth2ClientSecretFile;
        allowInsecureClientDisablePkce = true;
        preferShortUsername = true;
        scopeMaps.immich-users = [
          "openid"
          "email"
          "profile"
        ];
      };
    };

    services.immich = {
      enable = true;
      inherit (cfg) host port mediaLocation;

      machine-learning.enable = cfg.machineLearning.enable;

      settings = {
        machineLearning.enabled = cfg.machineLearning.enable;
        newVersionCheck.enabled = false;
        oauth = mkIf oidcEnabled {
          enabled = true;
          issuerUrl = "https://${kanidm.hostName}/oauth2/openid/immich";
          clientId = "immich";
          clientSecret._secret = oauth2ClientSecretFile;
          scope = "openid email profile";
          signingAlgorithm = "ES256";
          profileSigningAlgorithm = "none";
          tokenEndpointAuthMethod = "client_secret_post";
          buttonText = "Login with Kanidm";
          autoRegister = true;
          autoLaunch = false;
          mobileOverrideEnabled = true;
          mobileRedirectUri = "https://${cfg.hostName}/api/oauth/mobile-redirect";
        };
        passwordLogin.enabled = true;
        server.externalDomain = "https://${cfg.hostName}";
      };

      environment.IMMICH_MACHINE_LEARNING_ENABLED =
        if cfg.machineLearning.enable then "true" else "false";

      database = {
        enable = true;
        createDB = true;
      };

      redis.enable = true;
      openFirewall = mkDefault false;
    };

    systemd.services.immich-oauth2-secrets = mkIf oidcEnabled {
      description = "Generate Immich Kanidm OAuth2 secret";
      before = [
        "kanidm.service"
        "immich-server.service"
      ];
      requiredBy = [
        "kanidm.service"
        "immich-server.service"
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o root -g kanidm ${oauth2SecretDir}

        if [ ! -s ${oauth2ClientSecretFile} ]; then
          ${lib.getExe' pkgs.openssl "openssl"} rand -base64 48 | ${lib.getExe' pkgs.coreutils "tr"} -d '\n' > ${oauth2ClientSecretFile}
        fi

        ${lib.getExe' pkgs.coreutils "chown"} root:kanidm ${oauth2ClientSecretFile}
        ${lib.getExe' pkgs.coreutils "chmod"} 0440 ${oauth2ClientSecretFile}
      '';
    };
  };
}
