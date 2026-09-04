{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.my.kubernetes;
in
{
  options.my.kubernetes.enable = mkEnableOption "Kubernetes tooling";

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        helmfile
        kind
        kubeconform
        kubectl
        kubectx
        kubelogin
        kubernetes-helm
        kubeseal
        kustomize
        stern
      ];

      shellAliases = {
        k = "kubecolor";
        kc = "kubectx";
        kn = "kubens";
        ks = "kubeseal";
      };
    };

    programs = {
      k9s = {
        enable = true;
        package = pkgs.k9s;
        settings.k9s = {
          liveViewAutoRefresh = true;
          refreshRate = 1;
          maxConnRetry = 3;
          ui.enableMouse = true;
        };
      };

      kubecolor = {
        enable = true;
        enableAlias = true;
      };
    };
  };
}
