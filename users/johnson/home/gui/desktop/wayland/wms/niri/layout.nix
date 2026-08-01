{
  lib,
  config,
  ...
}:
let
  inherit (lib.modules) mkForce mkIf;
  cfg = config.my.gui.desktop.niri;
in
{
  config = mkIf cfg.enable {
    programs.niri.settings = {
      layout = {
        background-color = mkForce "transparent";
        shadow.enable = true;
        center-focused-column = "never";
        always-center-single-column = true;
        preset-column-widths = [
          { proportion = 1.0 / 3.0; }
          { proportion = 1.0 / 2.0; }
          { proportion = 2.0 / 3.0; }
          { proportion = 1.0; }
        ];
        preset-window-heights = [
          { proportion = 1.0 / 3.0; }
          { proportion = 1.0 / 2.0; }
          { proportion = 2.0 / 3.0; }
          { proportion = 1.0; }
        ];
        default-column-width = {
          proportion = 0.5;
        };
        focus-ring = {
          enable = true;
          width = 2;
        };
        border = {
          enable = false;
          width = 1;
        };
      };
    };
  };
}
