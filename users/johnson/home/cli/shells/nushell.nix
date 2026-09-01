{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkForce mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.my.nushell;
  nushellAbbrs = config.my.shellAbbrs // {
    mv = "^mv -iv";
    cp = "^cp -riv";
    mkdir = "^mkdir -vp";
    rmdir = "^rmdir -vp";
    gm = "git show-ref --verify --quiet refs/heads/main; if $env.LAST_EXIT_CODE == 0 { git checkout main } else { git checkout master }";
    ggc = "git reflog expire --expire-unreachable=now --all; if $env.LAST_EXIT_CODE == 0 { git gc --prune=now }";
  };
in
{
  options.my.nushell = {
    enable = mkEnableOption "Nushell" // {
      default = config.my.shell == "nushell";
    };
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      plugins = with pkgs.nushellPlugins; [
        formats
        gstat
        query
        polars
        skim
      ];
      configFile.source = lib.dot.relativeToConfig "nushell/config.nu";
      settings = {
        show_banner = false;
        auto_cd_implicit = true;
        edit_mode = "vi";
        buffer_editor = config.my.editor;
        cursor_shape = {
          vi_insert = "line";
          vi_normal = "block";
        };
        history = {
          file_format = "sqlite";
          max_size = 10000;
          sync_on_enter = true;
          isolation = false;
          path = "${config.xdg.stateHome}/nushell/history.sqlite3";
        };
        rm.always_trash = true;
        table.mode = "compact";
        completions = {
          algorithm = "fuzzy";
          case_sensitive = false;
          quick = true;
          partial = true;
          external = {
            enable = true;
            max_results = 200;
          };
        };
        abbreviations = lib.hm.nushell.mkNushellInline (lib.hm.nushell.toNushell { } nushellAbbrs);
        # Colors
        highlight_resolved_externals = lib.hm.nushell.mkNushellInline "not (sys host | get kernel_version | str contains \"microsoft-standard-WSL2\")";
      };
      environmentVariables = {
        PROMPT_INDICATOR = "";
        PROMPT_INDICATOR_VI_INSERT = "";
        PROMPT_INDICATOR_VI_NORMAL = "";
        PROMPT_MULTILINE_INDICATOR = "";
      };
      shellAliases = {
        # `home.shellAliases` contains POSIX expressions that Nushell cannot parse directly.
        n = mkForce "npm exec --";
        dfh = mkForce "^df -h | ^grep -v tmpfs";
        dush = mkForce "^du -sh * | ^sort -hr";
        pscpu = mkForce "^ps aux | ^sort -nr -k 3 | ^head -10";
        psmem = mkForce "^ps aux | ^sort -nr -k 4 | ^head -10";
      };
    };
  };
}
