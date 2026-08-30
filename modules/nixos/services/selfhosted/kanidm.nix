{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.dot.selfhosted.services.kanidm;
  services = config.dot.selfhosted.services;
  secretsFile = "${self}/secrets/services/kanidm.yaml";
  certDir = "/var/lib/kanidm/tls";
  cert = "${certDir}/fullchain.pem";
  key = "${certDir}/key.pem";
  provision = config.services.kanidm.provision;
  provisionStateJson = pkgs.writeText "selfhosted-kanidm-provision-state.json" (
    builtins.toJSON { inherit (provision) groups persons systems; }
  );
  finalProvisionState =
    if provision.extraJsonFile != null then
      ''
        <(${lib.getExe pkgs.yq-go} '. *+ load("${provision.extraJsonFile}") | (.. | select(type == "!!seq")) |= unique' ${provisionStateJson})
      ''
    else
      provisionStateJson;
  generatedOauthSecretServices =
    lib.optionals (services.code-server.enable && services.kanidm.enable) [
      "code-server-oauth2-secrets.service"
    ]
    ++ lib.optionals (services.paperless.enable && services.kanidm.enable) [
      "paperless-oauth2-secrets.service"
    ]
    ++ lib.optionals (services.dawarich.enable && services.kanidm.enable) [
      "dawarich-oauth2-secrets.service"
    ]
    ++ lib.optionals (services.fava.enable && services.kanidm.enable) [
      "fava-oauth2-secrets.service"
    ]
    ++ lib.optionals (services.copyparty.enable && services.kanidm.enable) [
      "copyparty-oauth2-secrets.service"
    ]
    ++ lib.optionals (services.immich.enable && services.kanidm.enable) [
      "immich-oauth2-secrets.service"
    ]
    ++ lib.optionals (services.pingvinShare.enable && services.kanidm.enable) [
      "pingvin-share-oidc-secret.service"
    ]
    ++ lib.optionals (services.seafile.enable && services.kanidm.enable) [
      "seafile-oidc-secret.service"
    ];
  oauthConsumerServices =
    lib.optionals (services.code-server.enable && services.kanidm.enable) [
      "oauth2-proxy-code-server.service"
    ]
    ++ lib.optionals (services.paperless.enable && services.kanidm.enable) [
      "paperless-web.service"
      "paperless-kanidm-admin.service"
    ]
    ++ lib.optionals (services.dawarich.enable && services.kanidm.enable) [
      "dawarich.target"
      "dawarich-init-db.service"
      "dawarich-web.service"
    ]
    ++ lib.optionals (services.fava.enable && services.kanidm.enable) [
      "oauth2-proxy-fava.service"
    ]
    ++ lib.optionals (services.copyparty.enable && services.kanidm.enable) [
      "oauth2-proxy-copyparty.service"
    ]
    ++ lib.optionals (services.immich.enable && services.kanidm.enable) [
      "immich-server.service"
    ]
    ++ lib.optionals (services.pingvinShare.enable && services.kanidm.enable) [
      "podman-pingvin-share.service"
    ]
    ++ lib.optionals (services.seafile.enable && services.kanidm.enable) [
      "podman-seafile.service"
    ];
  inherit (lib) getExe optionalString;
  inherit (lib.modules) mkIf;
in
{
  options.dot.selfhosted.services.kanidm = lib.dot.mkSelfhostedServiceOptions {
    inherit config;
    name = "kanidm";
    subdomain = "sso";
    defaultPort = 8443;
    scheme = "https";
  };

  config = mkIf cfg.enable {
    dot.selfhosted = {
      proxyBackends.kanidm = {
        inherit (cfg)
          host
          hostName
          localHostAlias
          port
          scheme
          ;
      };
      services.gatus.endpoints = [ (lib.dot.mkGatusEndpoint "kanidm" cfg) ];
      backups.paths = [ "/var/lib/kanidm" ];
    };

    sops.secrets = {
      kanidm-admin-password = {
        sopsFile = secretsFile;
        key = "admin-password";
        owner = "kanidm";
        group = "kanidm";
      };
      kanidm-idm-admin-password = {
        sopsFile = secretsFile;
        key = "idm-admin-password";
        owner = "kanidm";
        group = "kanidm";
      };
      kanidm-oauth2-forgejo = {
        sopsFile = secretsFile;
        key = "oauth2-forgejo";
        owner = "kanidm";
        group = "kanidm";
      };
      forgejo-kanidm-oauth2 = {
        sopsFile = secretsFile;
        key = "oauth2-forgejo";
        owner = "forgejo";
        group = "forgejo";
      };
      kanidm-oauth2-miniflux = {
        sopsFile = secretsFile;
        key = "oauth2-miniflux";
        owner = "kanidm";
        group = "kanidm";
      };
      kanidm-oauth2-wakapi = {
        sopsFile = secretsFile;
        key = "oauth2-wakapi";
        owner = "kanidm";
        group = "kanidm";
      };
      kanidm-oauth2-calibre = {
        sopsFile = secretsFile;
        key = "oauth2-calibre";
        owner = "kanidm";
        group = "kanidm";
      };
    };

    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning_1_11;
      server = {
        enable = true;
        settings = {
          version = "2";
          domain = cfg.hostName;
          origin = "https://${cfg.hostName}";
          bindaddress = "${cfg.host}:${toString cfg.port}";
          ldapbindaddress = null;
          tls_chain = cert;
          tls_key = key;
          online_backup = {
            path = "/var/lib/kanidm/backups";
            schedule = "00 22 * * *";
            versions = 7;
          };
        };
      };
      client = {
        enable = true;
        settings.uri = "https://${cfg.hostName}";
      };
      provision = {
        enable = true;
        adminPasswordFile = config.sops.secrets.kanidm-admin-password.path;
        idmAdminPasswordFile = config.sops.secrets.kanidm-idm-admin-password.path;
        instanceUrl = "https://${cfg.host}:${toString cfg.port}";
        acceptInvalidCerts = true;
        groups = {
          selfhosted-users.members = [ "johnson" ];
          forgejo-users.members = [ "johnson" ];
          forgejo-admins.members = [ "johnson" ];
          miniflux-users.members = [ "johnson" ];
          wakapi-users.members = [ "johnson" ];
          linkwarden-users.members = [ "johnson" ];
          calibre-users.members = [ "johnson" ];
        };
        persons.johnson = {
          displayName = "Johnson";
          legalName = "Johnson Hu";
          mailAddresses = [ config.dot.admin.email ];
          groups = [
            "selfhosted-users"
            "forgejo-users"
            "forgejo-admins"
            "miniflux-users"
            "wakapi-users"
            "linkwarden-users"
            "calibre-users"
          ];
        };
        systems.oauth2 = {
          forgejo = mkIf services.forgejo.enable {
            displayName = "Forgejo";
            originLanding = "https://${services.forgejo.hostName}/user/oauth2/Kanidm";
            originUrl = "https://${services.forgejo.hostName}/user/oauth2/Kanidm/callback";
            basicSecretFile = config.sops.secrets.kanidm-oauth2-forgejo.path;
            allowInsecureClientDisablePkce = true;
            preferShortUsername = true;
            scopeMaps.forgejo-users = [
              "openid"
              "email"
              "profile"
            ];
            claimMaps.forgejo_role = {
              joinType = "array";
              valuesByGroup.forgejo-admins = [ "admin" ];
            };
          };
          miniflux = mkIf services.miniflux.enable {
            displayName = "Miniflux";
            originLanding = "https://${services.miniflux.hostName}/oauth2/oidc/redirect";
            originUrl = "https://${services.miniflux.hostName}/oauth2/oidc/callback";
            basicSecretFile = config.sops.secrets.kanidm-oauth2-miniflux.path;
            preferShortUsername = true;
            scopeMaps.miniflux-users = [
              "openid"
              "email"
              "profile"
            ];
          };
          wakapi = mkIf services.wakapi.enable {
            displayName = "Wakapi";
            originLanding = "https://${services.wakapi.hostName}/oidc/kanidm/login";
            originUrl = "https://${services.wakapi.hostName}/oidc/kanidm/callback";
            basicSecretFile = config.sops.secrets.kanidm-oauth2-wakapi.path;
            allowInsecureClientDisablePkce = true;
            preferShortUsername = true;
            scopeMaps.wakapi-users = [
              "openid"
              "email"
              "profile"
            ];
          };
          linkwarden = mkIf services.linkwarden.enable {
            displayName = "Linkwarden";
            originLanding = "https://${services.linkwarden.hostName}/";
            originUrl = "https://${services.linkwarden.hostName}/api/v1/auth/callback/authentik";
            basicSecretFile = config.sops.secrets.kanidm-oauth2-linkwarden.path;
            preferShortUsername = true;
            enableLegacyCrypto = true;
            scopeMaps.linkwarden-users = [
              "openid"
              "email"
              "profile"
            ];
          };
          calibre = mkIf services.calibre.enable {
            displayName = "Calibre-Web";
            originLanding = "https://${services.calibre.hostName}/oauth2/start";
            originUrl = "https://${services.calibre.hostName}/oauth2/callback";
            basicSecretFile = config.sops.secrets.kanidm-oauth2-calibre.path;
            preferShortUsername = true;
            scopeMaps.calibre-users = [
              "openid"
              "email"
              "profile"
            ];
          };
        };
      };
    };

    systemd.services = {
      kanidm-selfsigned-cert = {
        description = "Generate local self-signed TLS certificate for Kanidm";
        before = [ "kanidm.service" ];
        requiredBy = [ "kanidm.service" ];
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o kanidm -g kanidm ${certDir}
          if [ ! -s ${cert} ] || [ ! -s ${key} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} req \
              -x509 \
              -newkey rsa:4096 \
              -sha256 \
              -days 3650 \
              -nodes \
              -keyout ${key} \
              -out ${cert} \
              -subj "/CN=${cfg.hostName}" \
              -addext "subjectAltName=DNS:${cfg.hostName},DNS:localhost,IP:127.0.0.1"
          fi
          ${lib.getExe' pkgs.coreutils "chown"} kanidm:kanidm ${cert} ${key}
          ${lib.getExe' pkgs.coreutils "chmod"} 0440 ${cert} ${key}
        '';
      };

      kanidm = {
        after = [ "kanidm-selfsigned-cert.service" ];
        requires = [ "kanidm-selfsigned-cert.service" ];
      };

      kanidm-oauth2-provision = mkIf (generatedOauthSecretServices != [ ]) {
        description = "Synchronize generated Kanidm OAuth2 client secrets";
        wantedBy = [ "multi-user.target" ];
        after = [ "kanidm.service" ] ++ generatedOauthSecretServices;
        requires = [ "kanidm.service" ] ++ generatedOauthSecretServices;
        before = oauthConsumerServices;
        requiredBy = oauthConsumerServices;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          count=0
          while ! ${getExe pkgs.curl} -L --silent --max-time 1 --connect-timeout 1 --fail \
            ${optionalString provision.acceptInvalidCerts "--insecure"} \
            ${provision.instanceUrl} >/dev/null
          do
            sleep 1
            if [ "$count" -eq 30 ]; then
              echo "Kanidm did not become ready for OAuth2 provisioning" >&2
              exit 1
            fi
            count=$((count + 1))
          done

          KANIDM_IDM_ADMIN_PASSWORD="$(${lib.getExe' pkgs.coreutils "cat"} ${config.sops.secrets.kanidm-idm-admin-password.path})"
          KANIDM_PROVISION_IDM_ADMIN_TOKEN="$KANIDM_IDM_ADMIN_PASSWORD" \
            ${getExe pkgs.kanidm-provision} \
              ${optionalString (!provision.autoRemove) "--no-auto-remove"} \
              ${optionalString provision.acceptInvalidCerts "--accept-invalid-certs"} \
              --url "${provision.instanceUrl}" \
              --state ${finalProvisionState}
        '';
      };
    };

    networking.hosts."127.0.0.1" = [ cfg.hostName ];
  };
}
