{
  config,
  lib,
  ...
}:
let
  shellAliases = {
    tree = "eza --git --icons --tree";
    l = "eza -lah";
  };
  cfg = config.my.eza;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.my.eza = {
    enable = mkEnableOption "eza";
  };

  config = mkIf cfg.enable {
    # A modern replacement for ‘ls’
    # useful in bash/zsh prompt, not in nushell.
    programs.eza = {
      enable = true;
      # Keep Nushell's structured `ls`; use `eza`, `l`, or `tree` explicitly.
      enableNushellIntegration = false;
      git = true;
      icons = "auto";
      extraOptions = [
        "-l"
        "-a"
        "--group"
        "--group-directories-first"
        "--no-user"
        "--no-time"
        "--no-permissions"
        "--octal-permissions"
      ];
    };

    home = {
      inherit shellAliases;
    };
  };
}
