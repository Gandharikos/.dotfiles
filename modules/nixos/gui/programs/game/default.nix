{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;

  inherit (config.dot) gui;
  cfg = config.dot.gui.game;
  qs = lib.getExe pkgs.quickshell;
in
{
  imports = [ ./native-game-fixes.nix ];

  options.dot.gui.game.enable = mkEnableOption "game tooling";

  config = mkIf (gui.enable && cfg.enable) {
    programs = {
      gamemode = {
        enable = true;
        enableRenice = true;
        settings = {
          general = {
            softrealtime = "auto";
            renice = 15;
          };
          custom = {
            start = "${qs} ipc call notifications disable";
            end = "${qs} ipc call notifications enable";
          };
        };
      };

      gamescope = {
        enable = true;
        enableWsi = true;
        capSysNice = true;
        args = [
          "--rt"
          "--expose-wayland"
        ];
      };

      steam = {
        enable = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        gamescopeSession = {
          enable = true;
          args = [
            "--rt"
            "--expose-wayland"
          ];
        };
      };
    };
  };
}
