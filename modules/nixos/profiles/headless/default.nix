{
  lib,
  config,
  ...
}:
let
  inherit (lib.dot) scanPaths;
  inherit (lib.modules) mkIf mkForce;
  inherit (config.dot.device) type;
  # NOTE: wsl can use graphical desktop by docker, but it's not recommended
  isHeadless = type == "wsl" || type == "server" || type == "mobile" || type == "vm";
  cfg = config.dot.profiles.headless;
in
{
  imports = scanPaths ./.;
  options.dot.profiles.headless.enable = lib.mkEnableOption "enable headless profile" // {
    default = isHeadless;
  };

  config = mkIf cfg.enable {
    dot.gui.enable = mkForce false;
    dot.nix.excludedInputs = [
      "dms"
      "hypr-dynamic-cursors"
      "hypridle"
      "hyprland"
      "niri"
      "noctalia"
      "noctalia-official-plugins"
      "noctalia-qs"
      "vicinae"
      "vicinae-extensions"
      "wallpapers"
    ];
  };
}
