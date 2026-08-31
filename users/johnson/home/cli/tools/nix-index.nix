{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.my.nix-index;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];

  options.my.nix-index = {
    enable = mkEnableOption "nix-index";
  };

  config = mkIf cfg.enable {
    programs = {
      nix-index-database.comma.enable = true;
      nix-index = {
        enable = true;

        enableBashIntegration = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
        enableZshIntegration = true;

        # link nix-inde database to ~/.cache/nix-index
        symlinkToCacheHome = true;
      };
    };
  };
}
