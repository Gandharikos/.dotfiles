{
  config,
  lib,
  pkgs,
  ...
}:
let
  shellAliases = {
    "g" = "git";
  };
  cfg = config.my.git;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.types) nullOr enum;
  inherit (lib.meta) getExe';
  cat' = getExe' pkgs.coreutils "cat";
  git' = getExe' pkgs.git "git";
  githubSecretPath = config.sops.secrets.github_token.path;
  forgejoHost = "git.huwenqiang.dev";
  forgejoSecretPath = config.sops.secrets.forgejo_token.path;
  tokenExportShell = ''
    if [ -f ${githubSecretPath} ]; then
      export GITHUB_TOKEN="$(${cat'} ${githubSecretPath})"
    fi
    if [ -f ${forgejoSecretPath} ]; then
      export FORGEJO_TOKEN="$(${cat'} ${forgejoSecretPath})"
    fi
  '';
in
{
  options.my.git = {
    enable = mkEnableOption "git";
    diff = mkOption {
      type = nullOr (enum [
        "riff"
        "delta"
      ]);
      default = "delta";
      description = "The git diff tool to use";
    };
  };

  config = mkIf cfg.enable {
    programs = {
      bash.initExtra = tokenExportShell;
      fish.shellInit = ''
        if test -f ${githubSecretPath}
          set -gx GITHUB_TOKEN (${cat'} ${githubSecretPath})
        end
        if test -f ${forgejoSecretPath}
          set -gx FORGEJO_TOKEN (${cat'} ${forgejoSecretPath})
        end
      '';
      nushell.extraEnv = ''
        if ('${githubSecretPath}' | path exists) {
          $env.GITHUB_TOKEN = (open --raw '${githubSecretPath}' | str trim)
        }
        if ('${forgejoSecretPath}' | path exists) {
          $env.FORGEJO_TOKEN = (open --raw '${forgejoSecretPath}' | str trim)
        }
      '';
      zsh.initContent = tokenExportShell;
      # Use riff instead of delta
      riff = mkIf (cfg.diff == "riff") {
        enable = true;
        enableGitIntegration = true;
      };
      delta = mkIf (cfg.diff == "delta") {
        enable = true;
        options = {
          features = mkDefault "side-by-side";
          navigate = true; # use n and N to move between diff sections
          line-numbers = true;
        };
      };
      git = {
        enable = true;
        lfs.enable = true;
        ignores = [
          ".*.sw?"
          ".direnv/"
          ".envrc"
          ".vscode"
          "result*"
          "node_modules"
        ];
        settings = {
          user = {
            inherit (config.my) email;
            name = config.my.fullName;
          };

          safe.directory = [ "${config.my.homeDirectory}/.dotfiles" ];

          color.ui = "auto";
          core.editor = "nvim";
          init.defaultBranch = "main";
          credential.helper = "store";
          github.user = "Gandharikos";
          push.autoSetupRemote = true;
          pull.rebase = true;
          rebase = {
            autosquash = true;
            autostash = true;
            # stat = true;
            updateRefs = true;
          };
          rerere = {
            autoupdate = true;
            enabled = true;
          };
          status.submoduleSummary = true;
          "filter \"lfs\"" = {
            process = "git-lfs filter-process";
            required = true;
            clean = "git-lfs clean -- %f";
            smudge = "git-lfs smudge -- %f";
          };
          diff = {
            algorithm = "histogram";
            tool = "nvimdiff";
            # word-diff = "color";
            renamelimit = 14000; # useful for kernel
            # how code movement in different colors then added and removed lines.
            colorMoved = true;

            # replace the a/ and b/ in your diff header output with where the diff is coming from, so i/ (index), w/ (working directory) or c/ commit.
            mnemonicPrefix = true;
          };
          aliases =
            let
              log = "log --show-notes='*' --abbrev-commit --pretty=format:'%Cred%h %Cgreen(%aD)%Creset -%C(bold red)%d%Creset %s %C(bold blue)<%an>% %Creset' --graph";
            in
            {
              # common aliases
              # add
              a = "add --patch";
              ad = "add";

              # branch
              b = "branch";
              ba = "branch -a"; # list remote branches
              bd = "branch --delete";
              bD = "branch -D";

              # commit
              c = "commit";
              ca = "commit --amend";
              cm = "commit --message";

              co = "checkout";
              cb = "checkout -b";
              pc = "checkout --patch";

              cl = "clone";

              # diff
              d = "diff";
              ds = "diff --staged";
              dc = "diff --cached";

              # show
              h = "show";
              h1 = "show HEAD^";
              h2 = "show HEAD^^";
              h3 = "show HEAD^^^";
              h4 = "show HEAD^^^^";
              h5 = "show HEAD^^^^^";

              # push & pull
              P = "push";
              Pf = "push --force-with-lease";
              p = "pull";
              pr = "pull --rebase";
              # rebase
              r = "rebase";
              ra = "rebase --abort";
              rc = "rebase --continue";
              ri = "rebase --interactive";
              # reset
              R = "reset";
              Rh = "reset --hard";

              # log
              l = log;
              la = "${log} --all";
              ll = "${log} --numstat";
              ls = "${log} --patch";

              # status
              s = "status --short --branch";
              st = "status";
              # stash
              S = "stash";
              Sc = "stash clear";
              Sh = "stash show --patch";
              Sl = "stash list";
              Sp = "stash pop";
              # ls = ''
              #   log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate'';
              # ll = ''
              #   log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate --numstat'';

              # aliases for submodule
              update = "submodule update --init --recursive";
              foreach = "submodule foreach";
            };
        };
      };
    };

    home = {
      inherit shellAliases;

      packages = with pkgs; [
        bfg-repo-cleaner
        git-absorb
        git-crypt
        # git-surgeon is packaged as reposurgeon in nixpkgs.
        reposurgeon
        git-filter-repo
        gitflow
        gitleaks
        gitlint
        tig

        # Installed and configured through programs.git.lfs.enable.
        # git-lfs

        # actions runner for github actions
        # act
        # actionlint
        # action-validator
        # for .gitignore
        gibo
        # gitAndTools.hub
      ];

      # `programs.git` will generate the config file: ~/.config/git/config
      # to make git use this config file, `~/.gitconfig` should not exist!
      #
      #    https://git-scm.com/docs/git-config#Documentation/git-config.txt---global
      activation.removeExistingGitconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        rm -f ~/.gitconfig
      '';
      activation.installForgejoCredential = lib.hm.dag.entryAfter [ "sops-nix" ] ''
        if [ -f ${forgejoSecretPath} ]; then
          forgejo_token="$(${cat'} ${forgejoSecretPath})"
          if [ -n "$forgejo_token" ]; then
            printf 'protocol=https\nhost=${forgejoHost}\nusername=${config.my.name}\npassword=%s\n\n' "$forgejo_token" \
              | ${git'} credential approve
          fi
        fi
      '';
    };

    sops.secrets = {
      github_token = { };
      forgejo_token = { };
    };
  };
}
