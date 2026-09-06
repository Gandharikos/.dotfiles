{
  inputs,
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib.lists) optional;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) toUpper;
  inherit (lib.trivial) mod;
  inherit (lib.dot) mkOmniwmWorkspaces;

  cfg = config.my.gui.desktop;
  inherit (cfg.workspace) number;

  omniwmLib = inputs.omniwm.lib;
  modKey = "Control+Option+Command";
  workspaceCount = if number > 9 then 9 else number;

  keyName = toUpper;

  workspace =
    i:
    let
      workspaceNumber = i + 1;
    in
    {
      layoutType = "default";
      monitorAssignment.type = if mod workspaceNumber 2 == 0 then "secondary" else "main";
    };

  inherit (omniwmLib) appRule;
in
{
  imports = [ inputs.omniwm.homeManagerModules.default ];

  config =
    mkIf
      (
        osConfig.dot.gui.enable
        && osConfig.dot.gui.desktop.type == "darwin"
        && osConfig.dot.gui.desktop.default == "omniwm"
      )
      {
        warnings = optional (number > 9) ''
          OmniWM only exposes direct hotkey actions for workspaces 1-9 in the current package; configured the first 9 workspaces from my.gui.desktop.workspace.number=${toString number}.
        '';

        programs.omniwm = {
          enable = true;
          launchd.enable = true;

          settings = {
            general = {
              hotkeysEnabled = true;
              systemHyperTrigger = "None";
              # Match the existing AeroSpace modKey: cmd-alt-ctrl. Shift remains available for move variants.
              hyperKeyModifiers = "Control+Option+Command";
              defaultLayoutType = "niri";
              ipcEnabled = true;
              updateChecksEnabled = true;
            };

            focus = {
              followsMouse = true;
              moveMouseToFocusedWindow = true;
              followsWindowToMonitor = true;
            };

            gaps = {
              size = 10.0;
              outer = {
                left = 5.0;
                bottom = 5.0;
                top = 5.0;
                right = 5.0;
              };
            };

            borders = {
              enabled = false;
            };

            niri = {
              visibleContainerCount = 2;
              centerFocusedColumn = "never";
              alwaysCenterSingleColumn = true;
              singleWindowFit = "fill";
              containerPrimarySpanPresets = [
                (1.0 / 3.0)
                (1.0 / 2.0)
                (2.0 / 3.0)
                1.0
              ];
              defaultContainerPrimarySpan = 0.5;
            };

            workspaceBar = {
              enabled = true;
              showLabels = true;
              showFloatingWindows = false;
              hideEmptyWorkspaces = false;
            };

            hotkeys =
              (omniwmLib.hotkeys {
                "toggleOverview" = "${modKey}+Tab";
                "toggleColumnTabbed" = "${modKey}+T";

                "focus.left" = "${modKey}+${keyName osConfig.dot.keyboard.keys.h}";
                "focus.down" = "${modKey}+${keyName osConfig.dot.keyboard.keys.j}";
                "focus.up" = "${modKey}+${keyName osConfig.dot.keyboard.keys.k}";
                "focus.right" = "${modKey}+${keyName osConfig.dot.keyboard.keys.l}";

                "moveColumn.left" = "${modKey}+Shift+${keyName osConfig.dot.keyboard.keys.h}";
                "moveColumn.right" = "${modKey}+Shift+${keyName osConfig.dot.keyboard.keys.l}";
                "moveWindowUp" = "${modKey}+Shift+${keyName osConfig.dot.keyboard.keys.k}";
                "moveWindowDown" = "${modKey}+Shift+${keyName osConfig.dot.keyboard.keys.j}";
                "consumeWindowIntoColumn" = "${modKey}+Left Arrow";
                "expelWindowFromColumn" = "${modKey}+Right Arrow";

                "toggleFullscreen" = "${modKey}+F";
                "toggleFocusedWindowFloating" = "${modKey}+Shift+F";
                "toggleContainerFullPrimarySpan" = "${modKey}+M";
                "expandContainerToAvailablePrimarySpan" = "${modKey}+Shift+M";
                "centerColumn" = "${modKey}+C";
                "cycleSizeForward" = "${modKey}+R";
                "cycleWindowSecondarySpanForward" = "${modKey}+Shift+R";
                "setContainerPrimarySpan.decrease10Percent" = "${modKey}+Minus";
                "setContainerPrimarySpan.increase10Percent" = "${modKey}+Equal";
                "setWindowSecondarySpan.decrease10Percent" = "${modKey}+Shift+Minus";
                "setWindowSecondarySpan.increase10Percent" = "${modKey}+Shift+Equal";

                "focusPrevious" = "Unassigned";
                "workspaceBackAndForth" = "${modKey}+Delete";
                "switchWorkspace.previous" = "${modKey}+Left Bracket";
                "switchWorkspace.next" = "${modKey}+Right Bracket";
                "moveColumnToWorkspaceUp" = "${modKey}+Shift+Left Bracket";
                "moveColumnToWorkspaceDown" = "${modKey}+Shift+Right Bracket";

                "focusMonitorPrevious" = "${modKey}+Comma";
                "focusMonitorNext" = "${modKey}+Period";
                "moveWorkspaceToMonitor.left" = "${modKey}+Shift+Comma";
                "moveWorkspaceToMonitor.right" = "${modKey}+Shift+Period";

                "openCommandPalette" = "${modKey}+Slash";
              })
              ++ (mkOmniwmWorkspaces modKey workspaceCount);

            workspaces = omniwmLib.workspaces (builtins.genList workspace workspaceCount);

            appRules = [
              (appRule "com.openai.codex" {
                minWidth = 800.0;
                minHeight = 600.0;
              })
              (appRule "com.eltima.cmd1.pro.mas" {
                minWidth = 950.0;
                minHeight = 550.0;
              })
              (appRule "com.google.Chrome" {
                minWidth = 500.0;
                minHeight = 375.0;
              })
              (appRule "dev.zed.Zed" {
                minWidth = 360.0;
                minHeight = 240.0;
              })
              (appRule "com.apple.Safari" {
                minWidth = 574.0;
                minHeight = 220.0;
              })
              (appRule "app.zen-browser.zen" {
                assignToWorkspace = "1";
                initialContainerPrimarySpan = 1.0;
                minWidth = 500.0;
                minHeight = 495.0;
              })
              (appRule "org.mozilla.com.zen.browser" {
                assignToWorkspace = "1";
                initialContainerPrimarySpan = 1.0;
                minWidth = 500.0;
                minHeight = 495.0;
              })
              (appRule "org.mozilla.com.zen.browser" {
                titleSubstring = "picture-in-picture";
                layout = "float";
                assignToWorkspace = "1";
              })
              (appRule "org.mozilla.firefox" {
                initialContainerPrimarySpan = 1.0;
                minWidth = 500.0;
                minHeight = 120.0;
              })
              (appRule "company.thebrowser.dia" {
                initialContainerPrimarySpan = 1.0;
                minWidth = 500.0;
                minHeight = 420.0;
              })
              (appRule "company.thebrowser.Browser" {
                assignToWorkspace = "1";
                initialContainerPrimarySpan = 1.0;
              })
              (appRule "com.microsoft.VSCode" {
                assignToWorkspace = "1";
              })
              (appRule "com.mitchellh.ghostty" {
                assignToWorkspace = "1";
                minWidth = 90.0;
                minHeight = 48.0;
              })
              (appRule "com.tencent.xinWeChat" {
                assignToWorkspace = "2";
              })
              (appRule "com.tencent.qq" {
                assignToWorkspace = "2";
              })
              (appRule "com.spotify.client" {
                assignToWorkspace = "9";
                minWidth = 800.0;
                minHeight = 600.0;
              })
              (appRule "com.hnc.Discord" {
                assignToWorkspace = "4";
                minWidth = 800.0;
                minHeight = 500.0;
              })
              (appRule "ru.keepcoder.Telegram" {
                assignToWorkspace = "4";
              })
              (appRule "com.microsoft.Outlook" {
                minWidth = 930.0;
                minHeight = 650.0;
              })
              (appRule "com.apple.MobileSMS" {
                minWidth = 660.0;
                minHeight = 320.0;
              })
            ];
          };
        };
      };
}
