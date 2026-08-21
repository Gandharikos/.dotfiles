{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.modules) mkIf;

  inherit (config.my.gui) desktop;
  cfg = desktop.idle;
  inherit (cfg) timeout;
  inherit (cfg.commands)
    lock
    lockSession
    screenOn
    screenOff
    dimScreen
    restoreScreen
    suspend
    keyboardBacklightOff
    keyboardBacklightOn
    ;

  enable = desktop.idle.default == "swayidle" && osConfig.dot.gui.desktop.wayland.enable;
in
{
  config = mkIf enable {
    home.shellAliases.caffeinate = "systemctl --user stop swayidle";

    services.swayidle = {
      enable = true;

      events = {
        before-sleep = lockSession;
        inherit lock;
      }
      // lib.optionalAttrs (screenOn != null) {
        after-resume = screenOn;
      };

      timeouts = [
        {
          timeout = timeout - 10;
          command = toString dimScreen;
          resumeCommand = restoreScreen;
        }
        {
          inherit timeout;
          command = lockSession;
        }
      ]
      ++ optionals cfg.keyboardBacklight.enable [
        {
          timeout = timeout / 2;
          command = keyboardBacklightOff;
          resumeCommand = keyboardBacklightOn;
        }
      ]
      ++ optionals (screenOff != null) [
        {
          inherit timeout;
          command = screenOff;
          resumeCommand = screenOn;
        }
      ]
      ++ optionals cfg.suspend.enable [
        {
          timeout = timeout + 10;
          command = toString suspend;
        }
      ];
    };
  };
}
