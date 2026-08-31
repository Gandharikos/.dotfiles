{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.zellij;
  autoStart = config.my.mux.autoStart && config.my.mux.default == "zellij";
  inherit (lib)
    mkEnableOption
    mkIf
    getExe
    mkOption
    types
    ;
  inherit (lib.modules) mkDefault;

  shell = getExe (builtins.getAttr config.my.shell pkgs);
in
{
  imports = lib.dot.scanPaths ./.;

  options.my.zellij = {
    enable = mkEnableOption "Zellij" // {
      default = config.my.mux.default == "zellij";
    };
    template = mkOption {
      internal = true;
      type = types.anything;
      default = {
        default_tab_template._children = [
          {
            pane = {
              size = 1;
              borderless = true;
              plugin.location = "zellij:tab-bar";
            };
          }
          { children = { }; }
          {
            pane = {
              size = 2;
              borderless = true;
              plugin.location = "zellij:status-bar";
            };
          }
        ];
      };
    };
  };

  config = mkIf cfg.enable {
    programs = {
      fish = mkIf config.programs.starship.enable {
        # force the function to load so it starts watching PWD
        interactiveShellInit = "_update_zellij_tab_name";
        functions."_update_zellij_tab_name" = {
          onEvent = "fish_prompt";
          onVariable = "PWD";
          body = ''
            set -l cwd (pwd)
            if git rev-parse --is-inside-worktree >/dev/null 2>&1
                # just show basename if inside a git worktree
                set cwd (basename "$cwd")
            else
                # otherwise, replace $HOME with ~ and truncate if needed
                set cwd (string replace "$HOME" "~" "$cwd")
                if test (string length "$cwd") -gt 30
                    set -l parts (string split / "$cwd")
                    set -l first (string join / $parts[1])
                    set -l last (string join / $parts[-1])
                    set cwd "$first/…/$last"
                end
            end
            set -l title "$cwd"
            command nohup zellij action rename-tab "$title" >/dev/null 2>&1
          '';
        };
      };

      zellij = {
        enable = true;
        enableFishIntegration = autoStart;
        enableBashIntegration = autoStart;
        enableZshIntegration = autoStart;
        exitShellOnExit = autoStart;
        settings = {
          default_mode = "normal";
          default_shell = shell;

          # UI
          pane_frames = false;
          simplified_ui = true;
          default_layout = mkDefault "compact";
          ui.pane_frames = {
            rounded_corners = true;
            hide_session_name = true;
          };
          show_startup_tips = false;

          # Mouse
          mouse_mode = true;
          copy_on_select = true;
          scrollback_editor = getExe config.programs.neovim.package;
          # TODO: add option that handles darwin and X11/Wayland
          copy_command =
            if pkgs.stdenv.hostPlatform.isDarwin then
              "pbcopy"
            else if pkgs.stdenv.hostPlatform.isLinux then
              "wl-copy"
            else
              "xclip -selection clipboard";

          # serialized
          serialize_pane_viewport = true;
          session_serialization = true;

          # web
          # https://zellij.dev/tutorials/web-client/
          # web_server = true;
          # Generated with `nix run nixpkgs#mkcert -install localhost 127.0.0.1`
          # web_server_cert = builtins.toString /etc/nixos/localhost+1.pem;
          # web_server_key = builtins.toString /etc/nixos/localhost+1-key.pem;
          enforce_https_over_localhost = true;
        };
      };
    };

    home = {
      shellAliases.z = "zellij";
    };
  };
}
