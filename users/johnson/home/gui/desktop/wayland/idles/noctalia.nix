{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (config.my.gui) desktop;

  idleCfg = desktop.idle;
  enable =
    osConfig.dot.gui.desktop.wayland.enable
    && idleCfg.default == "shell"
    && desktop.shell.default == "noctalia"
    && (config.programs.noctalia.enable or false);
  screenOffTimeout = lib.max 0 (idleCfg.timeout - 10);
  keyboardBacklightTimeout = idleCfg.timeout / 2;
in
{
  config = mkIf enable {
    programs.noctalia.settings.idle = {
      pre_action_fade_seconds = 5;
      behavior_order =
        lib.optional idleCfg.keyboardBacklight.enable "keyboard-backlight"
        ++ [
          "screen-off"
          "lock"
        ]
        ++ lib.optional idleCfg.suspend.enable "suspend";
      behavior = {
        "screen-off" = {
          enabled = true;
          timeout = screenOffTimeout;
          action = "screen_off";
          command = idleCfg.commands.screenOff;
          resume_command = idleCfg.commands.screenOn;
        };
        lock = {
          enabled = true;
          inherit (idleCfg) timeout;
          action = "lock";
          command = "noctalia:session lock";
        };
      }
      // lib.optionalAttrs idleCfg.suspend.enable {
        suspend = {
          enabled = true;
          timeout = idleCfg.timeout + 10;
          action = "suspend";
        };
      }
      // lib.optionalAttrs idleCfg.keyboardBacklight.enable {
        "keyboard-backlight" = {
          enabled = true;
          timeout = keyboardBacklightTimeout;
          action = "command";
          command = idleCfg.commands.keyboardBacklightOff;
          resume_command = idleCfg.commands.keyboardBacklightOn;
        };
      };
    };
  };
}
