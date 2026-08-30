{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dot.selfhosted.services.pingvinShare;
  kanidm = config.dot.selfhosted.services.kanidm;
  oidcEnabled = kanidm.enable;
  inherit (cfg) dataDir;
  secretDir = "${dataDir}/secrets";
  adminPasswordFile = "${secretDir}/admin-password";
  oidcClientSecretFile = "${secretDir}/oidc-client-secret";
  configFile = "${dataDir}/config.yaml";
  stateBackupDir = "${dataDir}/state-backup";
  uid = "10001";
  gid = "10001";
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) port str;
in
{
  options.dot.selfhosted.services.pingvinShare =
    lib.dot.mkSelfhostedServiceOptions {
      inherit config;
      name = "pingvinShare";
      displayName = "Pingvin Share X";
      subdomain = "share";
      defaultPort = 3005;
      defaultEnable = false;
    }
    // {
      dataDir = mkOption {
        type = str;
        default = "/var/lib/pingvin-share-x";
        description = "Pingvin Share X persistent data directory.";
      };

      image = mkOption {
        type = str;
        default = "ghcr.io/smp46/pingvin-share-x:v1.22.1";
        description = "Pinned Pingvin Share X OCI image.";
      };

      backendPort = mkOption {
        type = port;
        default = 8089;
        description = "Local Pingvin Share X API port.";
      };
    };

  config = mkIf cfg.enable {
    services.kanidm.provision = mkIf oidcEnabled {
      groups.pingvin-share-admins.members = [ "johnson" ];
      persons.johnson.groups = [ "pingvin-share-admins" ];
      systems.oauth2.pingvin-share = {
        displayName = "Pingvin Share X";
        originLanding = "https://${cfg.hostName}/auth/signIn";
        originUrl = "https://${cfg.hostName}/api/oauth/callback/oidc";
        basicSecretFile = oidcClientSecretFile;
        allowInsecureClientDisablePkce = true;
        preferShortUsername = true;
        scopeMaps.pingvin-share-admins = [
          "openid"
          "email"
          "profile"
        ];
        claimMaps.pingvin_roles = {
          joinType = "array";
          valuesByGroup.pingvin-share-admins = [ "admin" ];
        };
      };
    };

    dot = {
      virtual.podman.enable = true;
      selfhosted = {
        services.gatus.endpoints = [
          {
            name = "pingvin-share";
            url = "http://${cfg.host}:${toString cfg.backendPort}/api/health";
            interval = "1m";
            conditions = [ "[STATUS] == 200" ];
          }
        ];
        backups.paths = [ stateBackupDir ];
      };
    };

    networking.hosts."127.0.0.1" = [ cfg.hostName ];

    services.caddy.virtualHosts.${cfg.hostName} = {
      extraConfig = ''
        encode zstd gzip

        handle /api/* {
          reverse_proxy ${cfg.host}:${toString cfg.backendPort}
        }

        handle {
          reverse_proxy ${cfg.host}:${toString cfg.port}
        }
      '';
    };

    systemd.tmpfiles.settings.selfhosted-pingvin-share = {
      ${dataDir}.d = {
        user = uid;
        group = gid;
        mode = if oidcEnabled then "0751" else "0750";
      };
      "${dataDir}/data".d = {
        user = uid;
        group = gid;
        mode = "0750";
      };
      "${dataDir}/images".d = {
        user = uid;
        group = gid;
        mode = "0750";
      };
      ${secretDir}.d = {
        user = "root";
        group = if oidcEnabled then "kanidm" else "root";
        mode = if oidcEnabled then "0750" else "0700";
      };
      ${stateBackupDir}.d = {
        user = "root";
        group = "root";
        mode = "0700";
      };
    };

    virtualisation.oci-containers.containers.pingvin-share = {
      inherit (cfg) image;
      autoStart = true;
      environment = {
        CADDY_DISABLED = "true";
        TRUST_PROXY = "true";
        PORT = "3333";
        BACKEND_PORT = "8080";
        CONFIG_FILE = "/opt/app/config.yaml";
        PUID = uid;
        PGID = gid;
      };
      volumes = [
        "${dataDir}/data:/opt/app/backend/data:rw"
        "${dataDir}/images:/opt/app/frontend/public/img:rw"
        "${configFile}:/opt/app/config.yaml:ro"
      ];
      ports = [
        "${cfg.host}:${toString cfg.port}:3333"
        "${cfg.host}:${toString cfg.backendPort}:8080"
      ];
      extraOptions = [
        "--security-opt=no-new-privileges"
        "--stop-timeout=30"
      ]
      ++ lib.optional oidcEnabled "--add-host=${kanidm.hostName}:host-gateway";
    };

    systemd.services = {
      podman-pingvin-share = {
        after = [ "pingvin-share-storage.service" ];
        requires = [ "pingvin-share-storage.service" ];
        serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "10s";
        };
      };

      pingvin-share-storage = {
        description = "Prepare Pingvin Share X storage";
        before = [ "podman-pingvin-share.service" ];
        requiredBy = [ "podman-pingvin-share.service" ];
        after = lib.optional oidcEnabled "pingvin-share-oidc-secret.service";
        requires = lib.optional oidcEnabled "pingvin-share-oidc-secret.service";
        serviceConfig.Type = "oneshot";
        script = ''
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o ${uid} -g ${gid} ${dataDir}/data ${dataDir}/images
          ${lib.getExe' pkgs.coreutils "install"} -d -m ${
            if oidcEnabled then "0750" else "0700"
          } -o root -g ${if oidcEnabled then "kanidm" else "root"} ${secretDir}
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 -o root -g root ${stateBackupDir}

          if [ ! -s ${adminPasswordFile} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -hex 24 > ${adminPasswordFile}
          fi

          admin_password="$(${lib.getExe' pkgs.coreutils "cat"} ${adminPasswordFile})"
          ${lib.optionalString oidcEnabled ''
            oidc_client_secret="$(${lib.getExe' pkgs.coreutils "cat"} ${oidcClientSecretFile})"
          ''}
          ${lib.getExe' pkgs.coreutils "cat"} > ${configFile} <<EOF
          general:
            appName: Pingvin Share X
            appUrl: https://${cfg.hostName}
            secureCookies: "true"
            showHomePage: "true"
          share:
            allowRegistration: "false"
            allowUnauthenticatedShares: "false"
            maxExpiration: 30 days
            defaultExpiration: 14 days
            shareIdLength: "12"
            maxSize: "50000000000"
            zipCompressionLevel: "0"
            chunkSize: "10000000"
            autoOpenShareModal: "false"
            reverseShareSimpleOnly: "false"
            allowAdminAccessAllShares: "true"
            enableUserRecipients: "false"
            fileRetentionPeriod: 0 days
          email:
            enableShareEmailRecipients: "false"
            enableShareDownloadNotifications: "false"
            enableEmailVerification: "false"
          smtp:
            enabled: "false"
          oauth:
            allowRegistration: "false"
            disablePassword: "false"
            oidc-enabled: "${lib.boolToString oidcEnabled}"
            oidc-discoveryUri: "${lib.optionalString oidcEnabled "https://${kanidm.hostName}/oauth2/openid/pingvin-share/.well-known/openid-configuration"}"
            oidc-signOut: "false"
            oidc-scope: openid email profile
            oidc-usernameClaim: preferred_username
            oidc-rolePath: pingvin_roles
            oidc-roleGeneralAccess: admin
            oidc-roleAdminAccess: admin
            oidc-clientId: pingvin-share
            oidc-clientSecret: "${lib.optionalString oidcEnabled "$oidc_client_secret"}"
          s3:
            enabled: "false"
          initUser:
            enabled: true
            username: johnson
            email: ${config.dot.admin.email}
            password: "$admin_password"
            isAdmin: true
            ldapDN: ""
          EOF

          ${lib.getExe' pkgs.coreutils "chown"} root:root ${adminPasswordFile}
          ${lib.getExe' pkgs.coreutils "chown"} ${uid}:${gid} ${configFile}
          ${lib.getExe' pkgs.coreutils "chmod"} 0400 ${adminPasswordFile} ${configFile}
        '';
      };

      pingvin-share-oidc-secret = mkIf oidcEnabled {
        description = "Generate Pingvin Share X Kanidm OIDC secret";
        before = [
          "kanidm.service"
          "pingvin-share-storage.service"
        ];
        requiredBy = [
          "kanidm.service"
          "pingvin-share-storage.service"
        ];
        serviceConfig.Type = "oneshot";
        script = ''
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o root -g kanidm ${secretDir}

          if [ ! -s ${oidcClientSecretFile} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -hex 48 > ${oidcClientSecretFile}
          fi

          ${lib.getExe' pkgs.coreutils "chown"} root:kanidm ${oidcClientSecretFile}
          ${lib.getExe' pkgs.coreutils "chmod"} 0440 ${oidcClientSecretFile}
        '';
      };

      pingvin-share-state-backup = {
        description = "Back up Pingvin Share X SQLite state";
        unitConfig.ConditionPathExists = "${dataDir}/data/pingvin-share.db";
        serviceConfig = {
          Type = "oneshot";
          UMask = "0077";
        };
        script = ''
          snapshot="${stateBackupDir}/pingvin-share.db"
          ${lib.getExe pkgs.sqlite} ${dataDir}/data/pingvin-share.db ".timeout 30000" ".backup '$snapshot.tmp'"
          ${lib.getExe' pkgs.coreutils "mv"} "$snapshot.tmp" "$snapshot"
        '';
      };
    };

    systemd.timers.pingvin-share-state-backup = {
      description = "Daily Pingvin Share X state backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
    };
  };
}
