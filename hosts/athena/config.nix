{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  forgejo = config.dot.selfhosted.services.forgejo;
in
{
  imports = [
    (import ../common/disko/bios-ext4.nix {
      device = "/dev/sda";
      swapSize = "2G";
    })
    (import ./athena-volume.nix { })
  ];

  networking.domain = "huwenqiang.dev";

  sops.secrets.rsshub-access-key = {
    sopsFile = "${self}/secrets/services/rsshub.yaml";
    key = "access-key";
  };

  sops.templates.rsshub-env = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      ACCESS_KEY=${config.sops.placeholder.rsshub-access-key}
    '';
    restartUnits = [ "rsshub.service" ];
  };

  services.rsshub.secretFiles = [ config.sops.templates.rsshub-env.path ];

  sops.secrets.forgejo-actions-runner-token = {
    sopsFile = "${self}/secrets/services/forgejo.yaml";
    key = "actions-runner-token";
  };

  sops.templates.forgejo-actions-runner-env = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      TOKEN=${config.sops.placeholder.forgejo-actions-runner-token}
    '';
    restartUnits = [ "gitea-runner-athena.service" ];
  };

  services.forgejo.settings.actions.ENABLED = true;

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.athena = {
      enable = true;
      name = "athena";
      url = "https://${forgejo.hostName}";
      tokenFile = config.sops.templates.forgejo-actions-runner-env.path;
      labels = [
        "docker:docker://catthehacker/ubuntu:act-latest"
        "ubuntu-latest:docker://catthehacker/ubuntu:act-latest"
      ];
      settings.container = {
        network = "host";
        options = "--add-host=${forgejo.hostName}:127.0.0.1";
      };
    };
  };

  dot = {
    primaryUser = "johnson";
    virtual.podman.enable = true;
    users.johnson.home.my.direnv.enable = lib.mkForce false;
    kernel.tweaks.enable = true;

    boot = {
      initrd = {
        tweaks.enable = true;
        optimizeCompressor = false;
      };
    };

    profiles = {
      hetzner = {
        enable = true;
        ipv4 = "159.69.182.58";
        ipv6 = "2a01:4f8:c015:cfa3::1";
      };
      minimal.enable = true;
    };

    networking = {
      enableIPv6 = true;
      tailscale = {
        enable = true;
        autoConnect = true;
        role = "client";
        acceptRoutes = false;
        acceptDns = false;
      };
      vpn.enable = false;
    };

    yubikey.enable = false;
    persistence.enable = false;
    users.johnson.home.my = {
      atuin.enable = lib.mkForce false;
      fastfetch.startOnLogin = lib.mkForce false;
      git.enable = lib.mkForce false;
    };
    selfhosted = {
      enable = true;
      domain = "huwenqiang.dev";
      reverseProxy = "caddy";
      monitoring = "gatus";
      backup = "restic";
      backups.taildrop = {
        enable = true;
        target = "ymir";
      };
      services.mailserver = {
        enable = true;
        delivery = {
          mode = "relay";
          relay = {
            host = "mail.smtp2go.com";
            port = 587;
            username = "huwenqiang.dev";
            passwordSecretKey = "replay_password";
          };
        };
      };
      services.rsshub = {
        enable = true;
        localHostAlias = false;
      };
      services.code-server.enable = true;
      services.calibre.enable = true;
      services.seafile.enable = true;
      services.pingvinShare.enable = true;
      services.outline.enable = true;
      services.actual.enable = true;
      services.dawarich.enable = true;
      services.fava.enable = true;
      services.copyparty.enable = true;
      services.homepage.enable = true;
      services.paperless.enable = true;
      services.immich.enable = true;
      services.blog.enable = true;
      services.notes.enable = false;
      services.vikunja.enable = false;
      services.grafana.enable = true;
      services.prometheus.enable = true;
      services.loki.enable = true;
    };

    services = {
      btrbk.enable = false;
      zram.enable = true;
    };
  };
}
