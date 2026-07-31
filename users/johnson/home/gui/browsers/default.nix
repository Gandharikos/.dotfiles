{
  lib,
  pkgs,
  config,
  osConfig,
  osClass,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib.meta) getExe;
  inherit (lib.strings) escapeShellArgs hasInfix;
  inherit (lib.dot) withUWSMArgs;
  inherit (lib.types)
    enum
    nullOr
    str
    listOf
    coercedTo
    ;
  inherit (lib.dot) scanPaths;
  inherit (config.my.gui) browser;
  commandType = coercedTo str (
    value:
    if hasInfix " " value then
      throw ''
        `dot.gui.browser.command` accepts either an argv list or a single
        program path. Use a list for commands with arguments.
      ''
    else
      [ value ]
  ) (listOf str);
in
{
  imports = scanPaths ./.;

  options.my.gui.browser = {
    default = mkOption {
      type = nullOr (enum [
        "zen"
        "chromium"
        "firefox"
        "helium"
      ]);
      default = if osConfig.dot.gui.enable && osClass == "nixos" then "chromium" else null;
      description = "The browser to use";
    };
    desktopId = mkOption {
      type = str;
      default = "${browser.default}.desktop";
      description = "Desktop entry id used for XDG mime associations.";
    };
    command = mkOption {
      type = commandType;
      default =
        if browser.default == null then
          [ ]
        else if osConfig.dot.gui.desktop.uwsm.enable then
          withUWSMArgs pkgs browser.default
        else
          [
            getExe
            (builtins.getAttr browser.default pkgs)
          ];
      description = ''
        The argv form of the browser command. This is used by
        compositors like Niri that expect a program and its arguments
        as a list instead of a shell string.
      '';
    };

    exec = mkOption {
      type = str;
      default = escapeShellArgs browser.command;
      internal = true;
      readOnly = true;
      description = ''
        The shell-escaped browser command derived from
        `dot.gui.browser.command`.
      '';
    };
  };

  config = mkIf (browser.default != null) {
    home.sessionVariables = {
      BROWSER = "${browser.default}";
    };
  };
}
