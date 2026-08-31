{
  config,
  osConfig,
  lib,
  ...
}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkBefore;
  cfg = config.my.yazi;
in
with osConfig.dot.keyboard.keys;
{
  imports = lib.dot.scanPaths ./.;

  options.my.yazi = {
    enable = mkEnableOption "yazi";
  };

  config = mkIf cfg.enable {
    # terminal file manager
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      settings = {
        mgr = {
          sort_by = "natural";
          sort_sensitive = false;
          sort_reverse = false;
          linemode = "size";
          show_hidden = true;
        };
        preview = {
          tab_size = 2;
          max_width = 1000;
          max_height = 1000;
        };
        opener = {
          edit = [
            {
              run = ''$EDITOR "$@"'';
              block = true;
            }
            {
              run = ''code "$@"'';
              orphan = true;
            }
          ];
          play = [
            { run = ''mpv "$@"''; }
            { run = ''iina "$@"''; }
            {
              run = ''mediainfo \"$1\"; echo \"Press enter to exit\"; read'';
              block = true;
              desc = "Show media info";
            }
          ];
          archive = [
            {
              run = ''unar "$1"'';
              desc = "Extract here";
            }
            {
              run = ''/Applications/MacZip.app/Contents/MacOS/MacZip "$1"'';
              orphan = true;
              desc = "MacZip";
            }
          ];
        };

        rules = [
          {
            name = "*/";
            use = [
              "edit"
              "open"
              "reveal"
            ];
          }
          {
            mime = "text/*";
            use = [
              "edit"
              "reveal"
            ];
          }
          {
            mime = "image/*";
            use = [
              "open"
              "reveal"
            ];
          }
          {
            mime = "video/*";
            use = [
              "play"
              "reveal"
            ];
          }
          {
            mime = "audio/*";
            use = [
              "play"
              "reveal"
            ];
          }
          {
            mime = "inode/x-empty";
            use = [
              "edit"
              "reveal"
            ];
          }
          {
            mime = "application/json";
            use = [
              "edit"
              "reveal"
            ];
          }
          {
            mime = "*/javascript";
            use = [
              "edit"
              "reveal"
            ];
          }

          {
            mime = "application/zip";
            use = [
              "extract"
              "reveal"
              "archive"
            ];
          }
          {
            mime = "application/gzip";
            use = [
              "extract"
              "reveal"
              "archive"
            ];
          }
          {
            mime = "application/x-tar";
            use = [
              "extract"
              "reveal"
              "archive"
            ];
          }
          {
            mime = "application/x-bzip";
            use = [
              "extract"
              "reveal"
              "archive"
            ];
          }
          {
            mime = "application/x-bzip2";
            use = [
              "extract"
              "reveal"
              "archive"
            ];
          }
          {
            mime = "application/x-7z-compressed";
            use = [
              "extract"
              "reveal"
              "archive"
            ];
          }
          {
            mime = "application/x-rar";
            use = [
              "extract"
              "reveal"
              "archive"
            ];
          }
          {
            mime = "*";
            use = [
              "open"
              "reveal"
            ];
          }
        ];
      };
      keymap = {
        mgr = {
          prepend_keymap = mkBefore [
            {
              on = "w";
              run = ''shell "$SHELL" --block --confirm'';
              desc = "Open shell here";
            }
            {
              on = "W";
              run = "tasks_show";
            }

            # Navigation
            {
              on = k;
              run = "arrow -1";
            }
            {
              on = j;
              run = "arrow 1";
            }
            {
              on = h;
              run = "leave";
            }

            {
              on = H;
              run = "back";
            }
            {
              on = L;
              run = "forward";
            }

            {
              on = "<C-u>";
              run = "seek -5";
            }

            # Operation
            {
              on = o;
              run = "link";
            }
            {
              on = O;
              run = "link --relative";
            }

            # Find
            {
              on = n;
              run = "find_arrow";
            }
            {
              on = n;
              run = "find_arrow --previous";
            }

            # Tab
            {
              on = "[";
              run = "tab_switch -1 --relative";
            }
            {
              on = "]";
              run = "tab_switch 1 --relative";
            }
          ];
        };
        tasks.prepend_keymap = [
          {
            on = k;
            run = "arrow -1";
          }
          {
            on = j;
            run = "arrow 1";
          }
        ];
        select.prepend_keymap = [
          {
            on = k;
            run = "arrow -1";
          }
          {
            on = j;
            run = "arrow 1";
          }
          {
            on = k;
            run = "arrow -5";
          }
          {
            on = j;
            run = "arrow 5";
          }
        ];
        input.prepend_keymap = [
          {
            on = i;
            run = "insert";
          }

          # Navigation
          {
            on = h;
            run = "move -1";
          }
          {
            on = l;
            run = "move 1";
          }

          {
            on = H;
            run = "move -999";
          }
          {
            on = L;
            run = "move 999";
          }

          {
            on = e;
            run = "forward --end-of-word";
          }
        ];
        help.prepend_keymap = [
          # Navigation
          {
            on = k;
            run = "arrow -1";
          }
          {
            on = j;
            run = "arrow 1";
          }

          {
            on = k;
            run = "arrow -5";
          }
          {
            on = j;
            run = "arrow 5";
          }
        ];
        completion.prepend_keymap = [
          {
            on = "<C-u>";
            run = "arrow -1";
          }
          {
            on = "<C-d>";
            run = "arrow 1";
          }
        ];
      };
    };
  };
}
