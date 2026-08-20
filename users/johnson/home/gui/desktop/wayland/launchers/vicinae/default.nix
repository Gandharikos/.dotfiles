{
  inputs,
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) escapeShellArgs;
  inherit (config.my.gui) desktop;

  enable = osConfig.dot.gui.desktop.wayland.enable && desktop.launcher.default == "vicinae";
  vicinaePackage = inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
  vicinae = getExe vicinaePackage;
  vicinaeCmd = [
    vicinae
    "toggle"
  ];
  vicinaeToggle = escapeShellArgs vicinaeCmd;
  extensionPackages = inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system};
  browserLinkManifest = builtins.toJSON {
    name = "com.vicinae.vicinae";
    description = "IPC Native Messaging Host";
    path = "${vicinaePackage}/libexec/vicinae/vicinae-browser-link";
    type = "stdio";
    allowed_origins = [ "chrome-extension://kcmipingpfbohfjckomimmahknoddnke/" ];
  };
in
{
  imports = [
    inputs.vicinae.homeManagerModules.default
    ./language.nix
  ];

  config = mkIf enable {
    programs.vicinae = {
      enable = true;
      package = vicinaePackage;
      enableFirefoxIntegration = true;
      systemd.enable = true;

      settings = {
        close_on_focus_loss = true;
        consider_preedit = true;
        pop_to_root_on_close = true;
        search_files_in_root = true;
        favicon_service = "twenty";
        escape_key_behavior = "close_window";

        launcher_window = {
          opacity = 0.5;
          material = "blur";
          size = {
            width = 770;
            height = 480;
          };
          compact_mode.enabled = false;
          layer_shell = {
            enabled = true;
            keyboard_interactivity = "on_demand";
            layer = "top";
          };
        };

        providers = {
          applications.preferences = {
            launchPrefix = "uwsm app -- ";
          };
          snippets.preferences = {
            enabled = true;
            undo = true;
            prePasteDelay = "100";
            keyDelay = "5";
          };
        };
      };

      extensions =
        with extensionPackages;
        [
          brotab
          chromium-bookmarks
          mullvad
          nix
          process-manager
          wiktionary
          wifi-commander
        ]
        ++ optionals (osConfig.dot.gui.desktop.default == "hyprland") [
          hypr
          hypr-keybinds
          hyprland-monitors
        ]
        ++ optionals (osConfig.dot.gui.desktop.default == "niri") [
          niri
        ]
        ++ optionals config.my.gui.apps.zed.enable [
          zed-recents
        ];
    };

    programs.niri.settings.binds = {
      "${desktop.modKey}+Space".action.spawn = vicinaeCmd;
    };

    home.shellAliases = optionalAttrs enable {
      launcher = vicinaeToggle;
    };

    home.file = mkIf pkgs.stdenv.hostPlatform.isLinux (
      optionalAttrs config.programs.chromium.enable {
        ".config/chromium/NativeMessagingHosts/com.vicinae.vicinae.json" = {
          force = true;
          text = browserLinkManifest;
        };
      }
      // optionalAttrs config.programs.helium.enable {
        ".config/net.imput.helium/NativeMessagingHosts/com.vicinae.vicinae.json" = {
          force = true;
          text = browserLinkManifest;
        };
        ".config/helium/NativeMessagingHosts/com.vicinae.vicinae.json" = {
          force = true;
          text = browserLinkManifest;
        };
      }
    );
  };
}
