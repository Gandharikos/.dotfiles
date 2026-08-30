{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dot.selfhosted.services.seafile;
  kanidm = config.dot.selfhosted.services.kanidm;
  oidcEnabled = kanidm.enable;
  secretDir = "${cfg.dataDir}/secrets";
  envFile = "${cfg.dataDir}/seafile.env";
  dbEnvFile = "${cfg.dataDir}/mariadb.env";
  dbRootPasswordFile = "${secretDir}/db-root-password";
  dbPasswordFile = "${secretDir}/db-password";
  adminPasswordFile = "${secretDir}/admin-password";
  jwtPrivateKeyFile = "${secretDir}/jwt-private-key";
  oidcClientSecretFile = "${secretDir}/oidc-client-secret";
  seahubSettingsFile = "${cfg.dataDir}/shared/seafile/conf/seahub_settings.py";
  writeOidcConfig = pkgs.writeShellScript "seafile-write-oidc-config" ''
    set -eu

    if [ ! -f ${seahubSettingsFile} ]; then
      exit 1
    fi

    oidc_client_secret="$(${lib.getExe' pkgs.coreutils "cat"} ${oidcClientSecretFile})"
    ${lib.getExe' pkgs.python3 "python"} - <<'PY'
    from pathlib import Path

    path = Path("${seahubSettingsFile}")
    text = path.read_text()
    start = "# BEGIN dot.selfhosted seafile oauth"
    end = "# END dot.selfhosted seafile oauth"
    while start in text and end in text:
        before, rest = text.split(start, 1)
        _, after = rest.split(end, 1)
        text = before.rstrip() + "\n\n" + after.lstrip()
    path.write_text(text.rstrip() + "\n")
    PY

    ${lib.getExe' pkgs.coreutils "cat"} >> ${seahubSettingsFile} <<EOF

    # BEGIN dot.selfhosted seafile oauth
    ENABLE_OAUTH = True
    OAUTH_CLIENT_ID = "seafile"
    OAUTH_CLIENT_SECRET = "$oidc_client_secret"
    OAUTH_REDIRECT_URL = "https://${cfg.hostName}/oauth/callback/"
    OAUTH_PROVIDER = "kanidm"
    OAUTH_PROVIDER_DOMAIN = "kanidm"
    OAUTH_AUTHORIZATION_URL = "https://${kanidm.hostName}/ui/oauth2"
    OAUTH_TOKEN_URL = "https://${kanidm.hostName}/oauth2/token"
    OAUTH_USER_INFO_URL = "https://${kanidm.hostName}/oauth2/openid/seafile/userinfo"
    OAUTH_SCOPE = ["openid", "email", "profile"]
    OAUTH_ATTRIBUTE_MAP = {
        "sub": (True, "uid"),
        "email": (True, "email"),
        "name": (False, "name"),
    }
    OAUTH_CREATE_UNKNOWN_USER = False
    OAUTH_ACTIVATE_USER_AFTER_CREATION = True
    # END dot.selfhosted seafile oauth
    EOF

    ${lib.getExe' pkgs.coreutils "chown"} root:root ${seahubSettingsFile}
    ${lib.getExe' pkgs.coreutils "chmod"} 0600 ${seahubSettingsFile}
  '';
  mysqlUid = "999";
  mysqlGid = "999";
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.types) port str;
in
{
  options.dot.selfhosted.services.seafile =
    lib.dot.mkSelfhostedServiceOptions {
      inherit config;
      name = "seafile";
      displayName = "Seafile";
      subdomain = "cloud";
      defaultPort = 8085;
      defaultEnable = false;
    }
    // {
      dataDir = mkOption {
        type = str;
        default = "/var/lib/seafile";
        description = "Seafile persistent data directory.";
      };

      image = mkOption {
        type = str;
        default = "seafileltd/seafile-mc:12.0-latest";
        description = "Seafile OCI image.";
      };

      dbImage = mkOption {
        type = str;
        default = "mariadb:10.11";
        description = "MariaDB OCI image used by Seafile.";
      };

      memcachedImage = mkOption {
        type = str;
        default = "memcached:1.6.29";
        description = "Memcached OCI image used by Seafile.";
      };

      dbPort = mkOption {
        type = port;
        default = 3307;
        description = "Local MariaDB port used by Seafile.";
      };

      memcachedPort = mkOption {
        type = port;
        default = 11212;
        description = "Local Memcached port used by Seafile.";
      };

    };

  config = mkIf cfg.enable {
    services.kanidm.provision = mkIf oidcEnabled {
      groups.seafile-users.members = [ "johnson" ];
      persons.johnson.groups = [ "seafile-users" ];
      systems.oauth2.seafile = {
        displayName = "Seafile";
        originLanding = "https://${cfg.hostName}/accounts/login/";
        originUrl = "https://${cfg.hostName}/oauth/callback/";
        basicSecretFile = oidcClientSecretFile;
        allowInsecureClientDisablePkce = true;
        preferShortUsername = true;
        scopeMaps.seafile-users = [
          "openid"
          "email"
          "profile"
        ];
      };
    };

    dot = {
      virtual.podman.enable = true;
      selfhosted = {
        proxyBackends.seafile = {
          inherit (cfg)
            hostName
            localHostAlias
            host
            port
            scheme
            ;
        };
        services.gatus.endpoints = [ (lib.dot.mkGatusEndpoint "seafile" cfg) ];
        backups.paths = [ cfg.dataDir ];
      };
    };

    systemd.tmpfiles.settings.selfhosted-seafile = {
      ${cfg.dataDir}.d = {
        user = "root";
        group = "root";
        mode = if oidcEnabled then "0751" else "0750";
      };
      "${cfg.dataDir}/mysql".d = {
        user = mysqlUid;
        group = mysqlGid;
        mode = "0700";
      };
      "${cfg.dataDir}/shared".d = {
        user = "root";
        group = "root";
        mode = "0750";
      };
      ${secretDir}.d = {
        user = "root";
        group = if oidcEnabled then "kanidm" else "root";
        mode = if oidcEnabled then "0750" else "0700";
      };
    };

    virtualisation.oci-containers.containers = {
      seafile-db = {
        image = cfg.dbImage;
        autoStart = true;
        environmentFiles = [ dbEnvFile ];
        volumes = [ "${cfg.dataDir}/mysql:/var/lib/mysql" ];
        ports = [ "127.0.0.1:${toString cfg.dbPort}:3306" ];
        extraOptions = [ "--security-opt=no-new-privileges" ];
      };

      seafile-memcached = {
        image = cfg.memcachedImage;
        autoStart = true;
        cmd = [
          "memcached"
          "-m"
          "256"
        ];
        ports = [ "127.0.0.1:${toString cfg.memcachedPort}:11211" ];
        extraOptions = [
          "--cap-drop=ALL"
          "--network-alias=memcached"
          "--security-opt=no-new-privileges"
        ];
      };

      seafile = {
        inherit (cfg) image;
        autoStart = true;
        environmentFiles = [ envFile ];
        volumes = [ "${cfg.dataDir}/shared:/shared" ];
        ports = [ "${cfg.host}:${toString cfg.port}:80" ];
        extraOptions = [
          "--add-host=host.containers.internal:host-gateway"
          "--security-opt=no-new-privileges"
        ]
        ++ lib.optional oidcEnabled "--add-host=${kanidm.hostName}:host-gateway";
      };
    };

    systemd.services = {
      seafile-env = {
        description = "Generate Seafile container environment";
        before = [
          "podman-seafile.service"
          "podman-seafile-db.service"
        ];
        requiredBy = [
          "podman-seafile.service"
          "podman-seafile-db.service"
        ];
        after = lib.optional oidcEnabled "seafile-oidc-secret.service";
        requires = lib.optional oidcEnabled "seafile-oidc-secret.service";
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          ${lib.getExe' pkgs.coreutils "install"} -d -m ${
            if oidcEnabled then "0751" else "0750"
          } -o root -g root ${cfg.dataDir}
          ${lib.getExe' pkgs.coreutils "install"} -d -m ${
            if oidcEnabled then "0750" else "0700"
          } -o root -g ${if oidcEnabled then "kanidm" else "root"} ${secretDir}
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 -o ${mysqlUid} -g ${mysqlGid} ${cfg.dataDir}/mysql
          ${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o root -g root ${cfg.dataDir}/shared
          ${lib.getExe' pkgs.coreutils "chown"} -R ${mysqlUid}:${mysqlGid} ${cfg.dataDir}/mysql

          if [ ! -s ${dbRootPasswordFile} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -base64 32 > ${dbRootPasswordFile}
          fi
          if [ ! -s ${dbPasswordFile} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -base64 32 > ${dbPasswordFile}
          fi
          if [ ! -s ${adminPasswordFile} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -base64 24 > ${adminPasswordFile}
          fi
          if [ ! -s ${jwtPrivateKeyFile} ]; then
            ${lib.getExe' pkgs.openssl "openssl"} rand -base64 48 > ${jwtPrivateKeyFile}
          fi

          if [ -f ${seahubSettingsFile} ]; then
            existing_db_password="$(${lib.getExe' pkgs.python3 "python"} - <<'PY'
          import ast
          from pathlib import Path

          path = Path("${seahubSettingsFile}")
          try:
              tree = ast.parse(path.read_text())
              for node in tree.body:
                  if isinstance(node, ast.Assign):
                      for target in node.targets:
                          if isinstance(target, ast.Name) and target.id == "DATABASES":
                              databases = ast.literal_eval(node.value)
                              password = databases.get("default", {}).get("PASSWORD", "")
                              if password:
                                  print(password)
                              raise SystemExit
          except Exception:
              pass
          PY
            )"
            if [ -n "$existing_db_password" ]; then
              printf '%s\n' "$existing_db_password" > ${dbPasswordFile}
            fi
          fi

          if [ -f ${seahubSettingsFile} ]; then
            ${lib.getExe' pkgs.python3 "python"} - <<'PY'
          from pathlib import Path

          path = Path("${seahubSettingsFile}")
          text = path.read_text()
          blocks = [
              ("# BEGIN dot.selfhosted seafile oauth", "# END dot.selfhosted seafile oauth"),
              ("# BEGIN dot.selfhosted seafile sso", "# END dot.selfhosted seafile sso"),
          ]
          for start, end in blocks:
              while start in text and end in text:
                  before, rest = text.split(start, 1)
                  _, after = rest.split(end, 1)
                  text = before.rstrip() + "\n\n" + after.lstrip()
          path.write_text(text)
          PY
          fi

          ${lib.getExe' pkgs.coreutils "chown"} root:root ${dbRootPasswordFile} ${dbPasswordFile} ${adminPasswordFile} ${jwtPrivateKeyFile}
          ${lib.getExe' pkgs.coreutils "chmod"} 0600 ${dbRootPasswordFile} ${dbPasswordFile} ${adminPasswordFile} ${jwtPrivateKeyFile}
          ${lib.optionalString oidcEnabled ''
            ${lib.getExe' pkgs.coreutils "chown"} root:kanidm ${oidcClientSecretFile}
            ${lib.getExe' pkgs.coreutils "chmod"} 0440 ${oidcClientSecretFile}
          ''}

          db_root_password="$(${lib.getExe' pkgs.coreutils "cat"} ${dbRootPasswordFile})"
          db_password="$(${lib.getExe' pkgs.coreutils "cat"} ${dbPasswordFile})"
          admin_password="$(${lib.getExe' pkgs.coreutils "cat"} ${adminPasswordFile})"
          jwt_private_key="$(${lib.getExe' pkgs.coreutils "cat"} ${jwtPrivateKeyFile})"

          {
            printf 'MYSQL_ROOT_PASSWORD=%s\n' "$db_root_password"
            printf 'MYSQL_LOG_CONSOLE=true\n'
          } > ${dbEnvFile}

          {
            printf 'TIME_ZONE=UTC\n'
            printf 'SEAFILE_SERVER_HOSTNAME=${cfg.hostName}\n'
            printf 'SEAFILE_SERVER_PROTOCOL=${if config.dot.selfhosted.useHttps then "https" else "http"}\n'
            printf 'SITE_ROOT=/\n'
            printf 'NON_ROOT=false\n'
            printf 'SEAFILE_LOG_TO_STDOUT=true\n'
            printf 'ENABLE_SEADOC=false\n'
            printf 'ENABLE_NOTIFICATION_SERVER=false\n'
            printf 'JWT_PRIVATE_KEY=%s\n' "$jwt_private_key"
            printf 'CACHE_PROVIDER=memcached\n'
            printf 'MEMCACHED_HOST=seafile-memcached\n'
            printf 'MEMCACHED_PORT=11211\n'
            printf 'SEAFILE_MYSQL_DB_HOST=seafile-db\n'
            printf 'SEAFILE_MYSQL_DB_PORT=3306\n'
            printf 'SEAFILE_MYSQL_DB_USER=seafile\n'
            printf 'SEAFILE_MYSQL_DB_PASSWORD=%s\n' "$db_password"
            printf 'DB_USER=seafile\n'
            printf 'DB_PASSWORD=%s\n' "$db_password"
            printf 'INIT_SEAFILE_MYSQL_ROOT_PASSWORD=%s\n' "$db_root_password"
            printf 'SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db\n'
            printf 'SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db\n'
            printf 'SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db\n'
            printf 'INIT_SEAFILE_ADMIN_EMAIL=${config.dot.admin.email}\n'
            printf 'INIT_SEAFILE_ADMIN_PASSWORD=%s\n' "$admin_password"
            printf 'DB_HOST=seafile-db\n'
            printf 'DB_PORT=3306\n'
            printf 'DB_ROOT_PASSWD=%s\n' "$db_root_password"
            printf 'SEAFILE_ADMIN_EMAIL=${config.dot.admin.email}\n'
            printf 'SEAFILE_ADMIN_PASSWORD=%s\n' "$admin_password"
          } > ${envFile}

          ${lib.getExe' pkgs.coreutils "chown"} root:root ${envFile} ${dbEnvFile}
          ${lib.getExe' pkgs.coreutils "chmod"} 0600 ${envFile} ${dbEnvFile}

          ${lib.optionalString oidcEnabled ''
            if [ -f ${seahubSettingsFile} ]; then
              ${writeOidcConfig}
            fi
          ''}
        '';
      };

      seafile-oidc-secret = mkIf oidcEnabled {
        description = "Generate Seafile Kanidm OIDC secret";
        before = [
          "kanidm.service"
          "seafile-env.service"
        ];
        requiredBy = [
          "kanidm.service"
          "seafile-env.service"
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

      seafile-oidc-config = mkIf oidcEnabled {
        description = "Ensure Seafile Kanidm OIDC configuration exists";
        wantedBy = [ "multi-user.target" ];
        after = [
          "podman-seafile.service"
          "seafile-oidc-secret.service"
        ];
        requires = [
          "podman-seafile.service"
          "seafile-oidc-secret.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          count=0
          while [ ! -f ${seahubSettingsFile} ]; do
            if [ "$count" -eq 60 ]; then
              echo "Seafile did not create seahub_settings.py" >&2
              exit 1
            fi
            sleep 1
            count=$((count + 1))
          done

          before="$(${lib.getExe' pkgs.coreutils "sha256sum"} ${seahubSettingsFile})"
          ${writeOidcConfig}
          after="$(${lib.getExe' pkgs.coreutils "sha256sum"} ${seahubSettingsFile})"

          if [ "$before" != "$after" ]; then
            ${lib.getExe config.virtualisation.podman.package} restart seafile
          fi
        '';
      };

      podman-seafile-db = {
        after = [ "seafile-env.service" ];
        requires = [ "seafile-env.service" ];
      };

      podman-seafile = {
        after = [
          "seafile-env.service"
          "podman-seafile-db.service"
          "podman-seafile-memcached.service"
        ];
        requires = [
          "seafile-env.service"
          "podman-seafile-db.service"
          "podman-seafile-memcached.service"
        ];
      };
    };
  };
}
