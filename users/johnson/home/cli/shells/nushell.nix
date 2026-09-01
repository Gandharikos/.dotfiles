{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.modules) mkForce mkIf;
  inherit (lib.options) mkEnableOption;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  cfg = config.my.nushell;
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
        c = "clear";
        Q = "shutdown -h now";
        R = "reboot";
        mv = "^mv -iv";
        cp = "^cp -riv";
        mkdir = "^mkdir -vp";
        rmdir = "^rmdir -vp";
        v = "nvim";
        lzd = "lazydocker";
        ns = "netstat -tunlp";

        gi = "git clone";
        gl = "git l --color | devmoji --log --color | less -rXF";
        gs = "git st";
        gb = "git checkout -b";
        gc = "git commit";
        gca = "git commit --amend -a --no-edit";
        gpr = "git pr checkout";
        gcp = "git commit -p";
        gP = "git push";
        gp = "git pull";

        ta = "tmux attach";
        tat = "tmux attach -t";
        tad = "tmux attach -d -t";
        ts = "tmux new -s";
        tl = "tmux ls";
        tk = "tmux kill-session -t";

        # `home.shellAliases` contains POSIX expressions that Nushell cannot parse directly.
        n = mkForce "npm exec --";
        dfh = mkForce "^df -h | ^grep -v tmpfs";
        dush = mkForce "^du -sh * | ^sort -hr";
        pscpu = mkForce "^ps aux | ^sort -nr -k 3 | ^head -10";
        psmem = mkForce "^ps aux | ^sort -nr -k 4 | ^head -10";
      }
      // optionalAttrs isLinux {
        rp = "trash put";
        rl = "trash list";

        s = "systemctl";
        su = "systemctl --user";
        ss = "systemctl status";
        sl = "systemctl --type service --state running";
        slu = "systemctl --user --type service --state running";
        se = "sudo systemctl enable";
        sd = "sudo systemctl disable";
        sen = "sudo systemctl enable --now";
        sdn = "sudo systemctl disable --now";
        sr = "sudo systemctl restart";
        so = "sudo systemctl stop";
        sa = "sudo systemctl start";
        sf = "systemctl --failed --all";

        j = "journalctl";
        jb = "journalctl -b";
        jf = "journalctl --follow";
        jg = "journalctl -b --grep";
        ju = "journalctl --unit";
      };
    };
  };
}
