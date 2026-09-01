{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.meta) getExe;
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf str;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  curl' = getExe pkgs.curl;
in
{
  imports = lib.dot.scanPaths ./.;

  options.my.shellAbbrs = mkOption {
    type = attrsOf str;
    default = { };
    description = "Abbreviations shared by interactive shells";
  };

  config = {
    my.shellAbbrs = {
      c = "clear";
      Q = "shutdown -h now";
      R = "reboot";
      mv = "mv -iv";
      cp = "cp -riv";
      mkdir = "mkdir -vp";
      rmdir = "rmdir -vp";
      v = "nvim";
      lg = "lazygit";
      lzd = "lazydocker";
      ipy = "ipython";
      ns = "netstat -tunlp";

      # cd
      ".." = "cd ..";
      "..." = "cd ../..";
      ".3" = "cd ../../..";
      ".4" = "cd ../../../..";
      ".5" = "cd ../../../../..";

      # Git
      g = "git";
      gi = "git clone";
      gl = "git l --color | devmoji --log --color | less -rXF";
      gs = "git st";
      gb = "git checkout -b";
      gc = "git commit";
      gca = "git commit --amend -a --no-edit";
      gpr = "git pr checkout";
      gm = "git branch -l main | rg main > /dev/null 2>&1 && git checkout main || git checkout master";
      gcp = "git commit -p";
      gP = "git push";
      gp = "git pull";
      ggc = "git reflog expire --expire-unreachable=now --all && git gc --prune=now";

      # tmux
      t = "tmux";
      ta = "tmux attach";
      tat = "tmux attach -t";
      tad = "tmux attach -d -t";
      ts = "tmux new -s";
      tl = "tmux ls";
      tk = "tmux kill-session -t";
    }
    // optionalAttrs isLinux {
      # trashy
      rp = "trash put";
      rl = "trash list";
      rr = "trash list | fzf --multi | awk '{$1=$1;print}' | rev | cut -d ' ' -f1 | rev | xargs trash restore --match=exact --force";
      re = "trash list | fzf --multi | awk '{$1=$1;print}' | rev | cut -d ' ' -f1 | rev | xargs trash empty --match=exact --force";

      # systemctl
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

      # journalctl
      j = "journalctl";
      jb = "journalctl -b";
      jf = "journalctl --follow";
      jg = "journalctl -b --grep";
      ju = "journalctl --unit";
    };

    home = {
      shellAliases = {
        syslog = "journalctl -f";
        sysfail = "systemctl --failed";
        sysreload = "sudo systemctl daemon-reload";

        # Process monitoring
        psmem = "ps aux | sort -nr -k 4 | head -10";
        pscpu = "ps aux | sort -nr -k 3 | head -10";

        # Disk usage
        dush = "du -sh * | sort -hr";
        dfh = "df -h | grep -v tmpfs";

        weather = "${curl'} wttr.in";
      };
      sessionVariables.KEYBOARD_LAYOUT = osConfig.dot.keyboard.layout;
    };
  };
}
