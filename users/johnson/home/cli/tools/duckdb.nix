{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.duckdb;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.my.duckdb.enable = mkEnableOption "DuckDB CLI";

  config = mkIf cfg.enable {
    home.packages = [ pkgs.duckdb ];

    home.file.".duckdbrc".text = ''
      .startup_text none
      .maxrows 100
    '';
  };
}
