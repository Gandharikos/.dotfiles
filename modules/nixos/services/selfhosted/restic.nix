{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.dot.selfhosted;
  restic = cfg.backups.restic;
  secretsFile = "${self}/secrets/services/restic.yaml";
  exportPackage = lib.dot.mkSelfhostedExportPackage pkgs;
  taildropPackage = lib.dot.mkSelfhostedTaildropPackage pkgs config;
  backupPathsFile = pkgs.writeText "selfhosted-backup-paths" (lib.concatLines cfg.backups.paths);
  markSuccessPackage = pkgs.writeShellApplication {
    name = "selfhosted-restic-mark-success";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      install -d -m 0700 /var/lib/selfhosted-backup
      date +%s > /var/lib/selfhosted-backup/last-success
      printf 'restic\n' > /var/lib/selfhosted-backup/last-method
    '';
  };
  inherit (lib.modules) mkIf;
in
{
  config = mkIf (cfg.enable && cfg.backup == "restic") {
    environment.systemPackages = [ pkgs.restic ];

    sops.secrets.restic-password = {
      sopsFile = secretsFile;
      key = "password";
      mode = "0400";
    };

    services.restic.backups.selfhosted = {
      inherit (restic) repository;
      passwordFile = config.sops.secrets.restic-password.path;
      initialize = true;
      paths = [ ];
      dynamicFilesFrom = ''
        while IFS= read -r path; do
          [ -e "$path" ] && printf '%s\n' "$path"
        done < ${backupPathsFile}
      '';
      timerConfig = {
        OnCalendar = cfg.backups.schedule;
        RandomizedDelaySec = "30m";
        Persistent = true;
      };
      inherit (restic) pruneOpts;
      backupPrepareCommand = ''
        install -d -m 0700 ${cfg.backups.exportDir} "$(dirname ${restic.repository})"
        ${lib.getExe' pkgs.util-linux "runuser"} -u postgres -- ${lib.getExe' config.services.postgresql.package "pg_dumpall"} \
          | ${lib.getExe' pkgs.zstd "zstd"} -T0 -19 -o ${cfg.backups.postgresqlDumpFile}.tmp > /dev/null
        mv ${cfg.backups.postgresqlDumpFile}.tmp ${cfg.backups.postgresqlDumpFile}
        ${lib.getExe' exportPackage "selfhosted-export"} ${cfg.backups.exportDir}/selfhosted-latest.tar.zst
      '';
    };

    systemd.services.restic-backups-selfhosted = {
      onFailure = mkIf cfg.services.ntfy.enable [ "selfhosted-backup-alert@%n.service" ];
      serviceConfig.ExecStartPost = [
        "${lib.getExe' markSuccessPackage "selfhosted-restic-mark-success"}"
      ]
      ++ lib.optional cfg.backups.taildrop.enable "${lib.getExe' taildropPackage "selfhosted-taildrop-backup"}";
    };
  };
}
