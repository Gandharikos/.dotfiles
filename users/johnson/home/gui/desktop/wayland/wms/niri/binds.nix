{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.lists) foldl';
  inherit (lib.meta) getExe getExe';
  inherit (lib.modules) mkIf;
  inherit (lib.dot) uwsmAppArgs;
  modNum = lib.trivial.mod;
  inherit (config.my.gui)
    desktop
    terminal
    browser
    fileManager
    ;

  cfg = config.my.gui.desktop.niri;
  inherit (desktop) modKey;
  modShift = "${modKey}+Shift";
  modCtrl = "${modKey}+Ctrl";
  modAlt = "${modKey}+Alt";

  numWorkspaces = desktop.workspace.number;
  workspaceNumbers = lib.genList (i: i + 1) numWorkspaces;
  workspaceKey = n: toString (modNum n 10);
  mkWorkspaceBinds =
    modifier: actionName: actionValueFn:
    builtins.listToAttrs (
      builtins.map (n: {
        name = "${modifier}+${workspaceKey n}";
        value = {
          action = {
            "${actionName}" = actionValueFn n;
          };
        };
      }) workspaceNumbers
    );

  playerctl = getExe pkgs.playerctl;
  wpctl = getExe' pkgs.wireplumber "wpctl";
  brightnessctl = getExe pkgs.brightnessctl;
  playerctlCmd = args: uwsmAppArgs pkgs playerctl args;
  wpctlCmd = args: uwsmAppArgs pkgs wpctl args;
  brightnessctlCmd = args: uwsmAppArgs pkgs brightnessctl args;
  dmsEnabled = config.programs.dank-material-shell.enable or false;
  noctaliaEnabled = config.programs.noctalia.enable or false;
  shellHandlesXf86Binds = dmsEnabled || noctaliaEnabled;
  useNiriBuiltinShot =
    desktop.shot.default == "shell" && desktop.shell.default == "dank-material-shell" && !dmsEnabled;
  screenshotBinds =
    if useNiriBuiltinShot then
      {
        "Print".action.screenshot = [ ];
        "Shift+Print".action.screenshot-window.write-to-disk = true;
        "Ctrl+Print".action.screenshot-screen.write-to-disk = true;
        "${modKey}+Print".action.screenshot = [ ];
      }
    else
      { };

  xf86FallbackBinds =
    if shellHandlesXf86Binds then
      { }
    else
      {
        "XF86AudioPlay" = {
          allow-when-locked = true;
          action.spawn = playerctlCmd [ "play-pause" ];
        };
        "XF86AudioPause" = {
          allow-when-locked = true;
          action.spawn = playerctlCmd [ "play-pause" ];
        };
        "XF86AudioNext" = {
          allow-when-locked = true;
          action.spawn = playerctlCmd [ "next" ];
        };
        "XF86AudioPrev" = {
          allow-when-locked = true;
          action.spawn = playerctlCmd [ "previous" ];
        };
        "XF86AudioMute" = {
          allow-when-locked = true;
          action.spawn = wpctlCmd [
            "set-mute"
            "@DEFAULT_AUDIO_SINK@"
            "toggle"
          ];
        };
        "XF86AudioMicMute" = {
          allow-when-locked = true;
          action.spawn = wpctlCmd [
            "set-mute"
            "@DEFAULT_AUDIO_SOURCE@"
            "toggle"
          ];
        };
        "XF86AudioRaiseVolume" = {
          allow-when-locked = true;
          repeat = true;
          action.spawn = wpctlCmd [
            "set-volume"
            "-l"
            "1.0"
            "@DEFAULT_AUDIO_SINK@"
            "6%+"
          ];
        };
        "XF86AudioLowerVolume" = {
          allow-when-locked = true;
          repeat = true;
          action.spawn = wpctlCmd [
            "set-volume"
            "-l"
            "1.0"
            "@DEFAULT_AUDIO_SINK@"
            "6%-"
          ];
        };
        "XF86MonBrightnessUp" = {
          allow-when-locked = true;
          repeat = true;
          action.spawn = brightnessctlCmd [
            "--exponent"
            "s"
            "5%+"
          ];
        };
        "XF86MonBrightnessDown" = {
          allow-when-locked = true;
          repeat = true;
          action.spawn = brightnessctlCmd [
            "--exponent"
            "s"
            "5%-"
          ];
        };
        "XF86KbdBrightnessUp" = {
          allow-when-locked = true;
          repeat = true;
          action.spawn = brightnessctlCmd [
            "--device=*::kbd_backlight"
            "s"
            "10%+"
          ];
        };
        "XF86KbdBrightnessDown" = {
          allow-when-locked = true;
          repeat = true;
          action.spawn = brightnessctlCmd [
            "--device=*::kbd_backlight"
            "s"
            "10%-"
          ];
        };
        "XF86KbdLightOnOff" = {
          allow-when-locked = true;
          action.spawn = [
            "${getExe' pkgs.bash "bash"}"
            "-c"
            ''
              current=$(${brightnessctl} --device="*::kbd_backlight" get)
              if [ "$current" -eq 0 ]; then
                ${brightnessctl} --device="*::kbd_backlight" set 100%
              else
                ${brightnessctl} --device="*::kbd_backlight" set 0
              fi
            ''
          ];
        };
      };
in
with osConfig.dot.keyboard.keys;
{
  config = mkIf cfg.enable {
    programs.niri.settings = {
      screenshot-path = desktop.shot.path;

      binds = foldl' lib.attrsets.recursiveUpdate { } [
        {
          # Note: next-window and previous-window are not valid niri actions
          # Use Mod+Tab for toggle-overview instead, or focus-window-{up,down}
          "${modKey}+Return" = {
            repeat = false;
            action.spawn = terminal.command;
          };
          "${modKey}+B" = {
            repeat = false;
            action.spawn = browser.command;
          };
          "${modKey}+${E}" = {
            repeat = false;
            action.spawn = fileManager.command;
          };
          "${modKey}+Tab".action.toggle-overview = [ ];
          "${modKey}+Q".action.close-window = [ ];
          "${modKey}+Shift+Escape".action.quit.skip-confirmation = true;

          # Focus movement (Hyprland-like).
          "${modKey}+${H}".action.focus-column-left = [ ];
          "${modKey}+${L}".action.focus-column-right = [ ];
          "${modKey}+${K}".action.focus-window-up = [ ];
          "${modKey}+${J}".action.focus-window-down = [ ];

          # Move windows/columns.
          "${modKey}+Shift+${H}".action.move-column-left = [ ];
          "${modKey}+Shift+${L}".action.move-column-right = [ ];
          "${modKey}+Shift+${K}".action.move-window-up = [ ];
          "${modKey}+Shift+${J}".action.move-window-down = [ ];

          # Niri-specific column management.
          "${modKey}+Ctrl+${H}".action.consume-or-expel-window-left = [ ];
          "${modKey}+Ctrl+${L}".action.consume-or-expel-window-right = [ ];
          "${modKey}+T".action.toggle-column-tabbed-display = [ ];

          # Floating / fullscreen.
          "${modKey}+F".action.fullscreen-window = [ ];
          "${modKey}+Shift+F".action.toggle-window-floating = [ ];
          "${modKey}+M".action.maximize-column = [ ];
          "${modKey}+Shift+M".action.maximize-window-to-edges = [ ];
          "${modKey}+C".action.center-column = [ ];
          "${modKey}+R".action.switch-preset-column-width = [ ];
          "${modKey}+Shift+R".action.switch-preset-window-height = [ ];
          "${modKey}+Minus".action.set-column-width = "-10%";
          "${modKey}+Equal".action.set-column-width = "+10%";

          # Monitor focus / move workspace.
          "${modKey}+Comma".action.focus-monitor-left = [ ];
          "${modKey}+Period".action.focus-monitor-right = [ ];
          "${modKey}+Shift+Comma".action.move-workspace-to-monitor-left = [ ];
          "${modKey}+Shift+Period".action.move-workspace-to-monitor-right = [ ];

          # Workspace navigation.
          "${modKey}+BracketLeft".action.focus-workspace-up = [ ];
          "${modKey}+BracketRight".action.focus-workspace-down = [ ];
          "${modKey}+Shift+BracketLeft".action.move-column-to-workspace-up = [ ];
          "${modKey}+Shift+BracketRight".action.move-column-to-workspace-down = [ ];
          "${modKey}+Backspace".action.focus-workspace-up = [ ];

          # Hotkey overlay.
          "${modKey}+Slash".action.show-hotkey-overlay = [ ];
        }
        screenshotBinds
        xf86FallbackBinds
        (mkWorkspaceBinds modKey "focus-workspace" (n: n))
        (mkWorkspaceBinds modShift "move-window-to-workspace" (n: n))
        (mkWorkspaceBinds modCtrl "move-window-to-workspace" (n: [
          { focus = false; }
          n
        ]))
        (mkWorkspaceBinds modAlt "move-column-to-workspace" (n: n))
      ];
    };
  };
}
