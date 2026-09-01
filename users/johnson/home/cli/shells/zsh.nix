{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.my.zsh;
in
{
  options.my.zsh = {
    enable = mkEnableOption "zsh" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      defaultKeymap = "viins";
      autosuggestion = {
        enable = true;
      };
      enableCompletion = true;
      syntaxHighlighting = {
        enable = true;
      };
      autocd = true;
      localVariables = {
        KEYTIMEOUT = "1";
        ZSH_AUTOSUGGEST_USE_ASYNC = "true";
        ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE = 40;
        ZSH_AUTOSUGGEST_STRATEGY = [
          "history"
          "completion"
        ];
      };
      dirHashes = {
        dot = "$HOME/.dotfiles";
        dow = "$HOME/Downloads";
        doc = "$HOME/Documents";
        one = "$HOME/OneDrive";
        desk = "$HOME/Desktop";
        pro = "$HOME/Projects";
        repo = "$HOME/Repos";
        pic = "$HOME/Pictures";
        work = "$HOME/Workspaces";
      };
      history = {
        path = "$HOME/.zsh_history";
        ignoreDups = true;
        ignoreSpace = true;
        extended = true;
        share = true;
        save = 10000;
        expireDuplicatesFirst = true;
        ignorePatterns = [
          "ls *"
          "rm *"
          "kill *"
          "exit *"
          "pkill *"
        ];
      };
      historySubstringSearch = {
        enable = true;
      };
      completionInit = ''
        zstyle ':completion:*' completer _expand _complete _ignored _approximate
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
        zstyle ':completion:*' menu select=2
        zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
        zstyle ':completion:*:descriptions' format '-- %d --'
        zstyle ':completion:*:processes' command 'ps -au$USER'
        zstyle ':completion:complete:*:options' sort false
        zstyle ':fzf-tab:complete:_zlua:*' query-string input
        zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm,cmd -w -w"
        zstyle ':fzf-tab:complete:kill:argument-rest' extra-opts --preview=$extract'ps --pid=$in[(w)1] -o cmd --no-headers -w -w' --preview-window=down:3:wrap
        zstyle ":completion:*:git-checkout:*" sort false
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      '';
      plugins = with pkgs; [
        {
          # Must be before plugins that wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
          name = "fzf-tab";
          src = zsh-fzf-tab;
          file = "share/fzf-tab";
        }
        {
          name = "zsh-nix-shell";
          src = zsh-nix-shell;
          file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
        }
        {
          name = "zsh-vi-mode";
          src = zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
        {
          name = "fast-syntax-highlighting";
          src = zsh-fast-syntax-highlighting;
          file = "share/zsh/site-functions";
        }
        {
          name = "zsh-autosuggestions";
          src = zsh-autosuggestions;
          file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
        }
        {
          name = "zsh-autopair";
          src = zsh-autopair;
          file = "share/zsh/zsh-autopair/autopair.zsh";
        }
        {
          name = "zsh-nix-shell";
          src = zsh-nix-shell;
          file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
        }
        {
          name = "you-should-use";
          inherit (zsh-you-should-use) src;
        }
      ];
      zsh-abbr = {
        enable = true;
        abbreviations = config.my.shellAbbrs;
      };
    };
  };
}
