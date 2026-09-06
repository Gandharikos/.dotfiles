{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.my.tailcat;
  tailcat = inputs.tailcat.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (_old: {
    # TODO: Remove this override after updating tailcat to a revision with stable E2E tests.
    doCheck = false;
  });
in
{
  options.my.tailcat.enable = mkEnableOption "Tailcat";

  config = mkIf cfg.enable {
    home.packages = [ tailcat ];
  };
}
