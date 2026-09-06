{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.types) enum nullOr str;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  inherit (lib.meta) getExe;
  inherit (config) dot;

  waylandChoices = [
    "hyprland"
    "niri"
    "cosmic"
  ];
  uwsmChoices = [
    "hyprland"
    "niri"
  ];
  xorgChoices = [
    "i3"
    "bspwm"
    "awesome"
  ];
  darwinChoices = [
    "aerospace"
    "omniwm"
  ];
in
{
  # Top-level GUI enable option
  options.dot.gui.enable = mkEnableOption "GUI" // {
    default = true;
  };

  # Desktop configuration options
  options.dot.gui.desktop = {
    type = mkOption {
      type = enum (
        if isLinux then
          [
            "wayland"
            "xorg"
          ]
        else
          [ "darwin" ]
      );
      default = if isLinux then "wayland" else "darwin";
      description = "The desktop environment type to use";
    };

    wayland.enable = mkEnableOption "Wayland desktop" // {
      default = dot.gui.enable && dot.gui.desktop.type == "wayland";
      internal = true;
      readOnly = true;
    };

    xorg.enable = mkEnableOption "Xorg desktop" // {
      default = dot.gui.enable && dot.gui.desktop.type == "xorg";
      internal = true;
      readOnly = true;
    };

    default = mkOption {
      type = enum (
        if dot.gui.desktop.type == "wayland" then
          waylandChoices
        else if dot.gui.desktop.type == "xorg" then
          xorgChoices
        else
          darwinChoices
      );
      default =
        if dot.gui.desktop.type == "wayland" then
          "hyprland"
        else if dot.gui.desktop.type == "xorg" then
          "i3"
        else
          "aerospace";
      description = "The default window manager limited by desktop.type";
    };

    shell = mkOption {
      type = nullOr (enum [
        "dank-material-shell"
        "noctalia"
      ]);
      default = if isLinux && dot.gui.desktop.wayland.enable then "noctalia" else null;
      description = "The desktop shell to use.";
    };

    uwsm.enable = mkEnableOption "UWSM-managed desktop session" // {
      default = dot.gui.desktop.wayland.enable && builtins.elem dot.gui.desktop.default uwsmChoices;
      internal = true;
      readOnly = true;
    };

    exec = mkOption {
      type = str;
      default = getExe (builtins.getAttr dot.gui.desktop.default pkgs);
      description = ''
        The command to use for logging in. This is used by the
        `dot.gui.desktop.exec` module to determine which command to run.
      '';
    };
  };
}
