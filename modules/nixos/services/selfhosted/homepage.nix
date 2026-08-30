{
  config,
  lib,
  ...
}:
let
  selfhosted = config.dot.selfhosted;
  cfg = selfhosted.services.homepage;

  inherit (lib.modules) mkIf;

  serviceUrl = service: "https://${service.hostName}";
in
{
  options.dot.selfhosted.services.homepage = lib.dot.mkSelfhostedServiceOptions {
    inherit config;
    name = "homepage";
    displayName = "Homepage Dashboard";
    subdomain = "home";
    defaultPort = 8087;
  };

  config = mkIf cfg.enable {
    dot.selfhosted = {
      proxyBackends.homepage = {
        inherit (cfg)
          host
          hostName
          localHostAlias
          port
          scheme
          ;
      };
      services.gatus.endpoints = [ (lib.dot.mkGatusEndpoint "homepage" cfg) ];
      backups.paths = [ "/var/lib/homepage-dashboard" ];
    };

    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.port;
      allowedHosts = "${cfg.hostName},localhost:${toString cfg.port},127.0.0.1:${toString cfg.port}";

      settings = {
        title = "Johnson";
        startUrl = "https://${cfg.hostName}";
        theme = "dark";
        color = "slate";
        language = "en";
        layout = {
          Core = {
            style = "row";
            columns = 4;
          };
          Knowledge = {
            style = "row";
            columns = 4;
          };
          Tools = {
            style = "row";
            columns = 4;
          };
          Operations = {
            style = "row";
            columns = 4;
          };
        };
      };

      widgets = [
        {
          search = {
            provider = "duckduckgo";
            target = "_blank";
          };
        }
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
        {
          datetime = {
            text_size = "xl";
            format = {
              dateStyle = "medium";
              timeStyle = "short";
              hourCycle = "h23";
            };
          };
        }
      ];

      services = [
        {
          Core = [
            {
              SSO = {
                href = serviceUrl selfhosted.services.kanidm;
                description = "Identity provider";
                icon = "kanidm.svg";
              };
            }
            {
              Forgejo = {
                href = serviceUrl selfhosted.services.forgejo;
                description = "Git hosting";
                icon = "forgejo.svg";
              };
            }
            {
              Vaultwarden = {
                href = serviceUrl selfhosted.services.vaultwarden;
                description = "Password vault";
                icon = "vaultwarden.svg";
              };
            }
            {
              Copyparty = {
                href = serviceUrl selfhosted.services.copyparty;
                description = "Private file transfer";
                icon = "copyparty.svg";
              };
            }
          ];
        }
        {
          Knowledge = [
            {
              Miniflux = {
                href = serviceUrl selfhosted.services.miniflux;
                description = "RSS reader";
                icon = "miniflux.svg";
              };
            }
            {
              Linkwarden = {
                href = serviceUrl selfhosted.services.linkwarden;
                description = "Bookmarks";
                icon = "linkwarden.svg";
              };
            }
            {
              Paperless = {
                href = serviceUrl selfhosted.services.paperless;
                description = "Documents";
                icon = "paperless-ngx.svg";
              };
            }
            {
              Notes = {
                href = serviceUrl selfhosted.services.notes;
                description = "Public notes";
                icon = "quartz.svg";
              };
            }
          ];
        }
        {
          Tools = [
            {
              Code = {
                href = serviceUrl selfhosted.services.code-server;
                description = "Remote editor";
                icon = "code-server.svg";
              };
            }
            {
              Wakapi = {
                href = serviceUrl selfhosted.services.wakapi;
                description = "Coding activity";
                icon = "wakapi.svg";
              };
            }
            {
              Budget = {
                href = serviceUrl selfhosted.services.actual;
                description = "Actual Budget";
                icon = "actual-budget.svg";
              };
            }
            {
              Photos = {
                href = serviceUrl selfhosted.services.immich;
                description = "Photo library";
                icon = "immich.svg";
              };
            }
          ];
        }
        {
          Operations = [
            {
              Status = {
                href = serviceUrl selfhosted.services.gatus;
                description = "Service status";
                icon = "gatus.svg";
              };
            }
            {
              Monitor = {
                href = serviceUrl selfhosted.services.grafana;
                description = "Metrics and logs";
                icon = "grafana.svg";
              };
            }
            {
              Cloud = {
                href = serviceUrl selfhosted.services.seafile;
                description = "Seafile";
                icon = "seafile.svg";
              };
            }
            {
              Tasks = {
                href = serviceUrl selfhosted.services.vikunja;
                description = "Tasks";
                icon = "vikunja.svg";
              };
            }
          ];
        }
      ];

      bookmarks = [
        {
          Development = [
            {
              "NixOS Options" = [
                {
                  abbr = "NO";
                  href = "https://search.nixos.org/options";
                }
              ];
            }
            {
              "NixOS Packages" = [
                {
                  abbr = "NP";
                  href = "https://search.nixos.org/packages";
                }
              ];
            }
          ];
        }
      ];
    };
  };
}
