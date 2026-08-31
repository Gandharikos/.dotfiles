{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  cfg = config.my.fzf;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkAfter;
  inherit (lib.meta) getExe;
  inherit (lib.strings) optionalString concatStringsSep;
  find' = "${getExe pkgs.fd} --type f --hidden --exclude=.git";
  delta' = getExe pkgs.delta;
  fd_opts = "--hidden --exclude=.git --exclude=.github --exclude=.cache";
  eza_opts = concatStringsSep " " config.programs.eza.extraOptions;
in
{
  options.my.fzf = {
    enable = mkEnableOption "fzf";
  };

  config = mkIf cfg.enable {
    programs = {
      fish = {
        plugins = with pkgs.fishPlugins; [
          {
            name = "fzf-fish";
            inherit (fzf-fish) src;
          }
          {
            name = "fifc";
            inherit (fifc) src;
          }
        ];
        interactiveShellInit = ''
          # fzf.fish plugin
          fzf_configure_bindings --variables=\cv --processes=\ep --git_status=\cs --git_log=\cg --directory=\ef
          set -gx fzf_fd_opts ${fd_opts}
          ${optionalString config.programs.eza.enable "set -gx fzf_preview_dir_cmd ${getExe pkgs.eza} ${eza_opts}"}
          ${optionalString config.programs.bat.enable "set -gx fzf_preview_file_cmd ${getExe pkgs.bat}"}
          set -gx fzf_diff_highlighter ${delta'} --paging=never --width=20

          # fifc plugin
          set -gx fifc_editor ${config.home.sessionVariables.VISUAL}
          set -gx fifc_fd_opts ${fd_opts}
          set -gx fifc_eza_opts ${eza_opts}
        '';
        functions.fish_user_key_bindings.body = mkAfter ''
          # Rebind Tab to fifc after resetting vi key bindings
          bind -M default \t _fifc
          bind -M insert \t _fifc
        '';
      };
      fzf = {
        enable = true;

        enableFishIntegration = true;
        enableBashIntegration = true;
        enableNushellIntegration = true;
        enableZshIntegration = true;

        defaultCommand = find';
        defaultOptions = [
          "--cycle"
          "--layout=reverse"
          "--height=60%"
          "--ansi"
          "--preview-window=right:70%"
          "--bind=ctrl-u:half-page-up,ctrl-d:half-page-down,ctrl-x:jump"
          "--bind=ctrl-f:preview-page-down,ctrl-b:preview-page-up"
          "--bind=ctrl-a:beginning-of-line,ctrl-e:end-of-line"
          "--prompt="
          "--pointer="
          "--marker=│"
          "--separator=─"
          "--scrollbar=│"
        ]
        ++ (
          if (osConfig.dot.keyboard.layout == "colemak") then
            [
              "--bind=ctrl-e:down,ctrl-i:up"
            ]
          else
            [
              "--bind=ctrl-j:down,ctrl-k:up"
            ]
        );

        fileWidget = {
          command = find';
          options = [ "--preview 'head {}'" ];
        };

        changeDirWidget = {
          command = find';
          options = [
            "--preview 'tree -C {} | head -200'"
          ];
        };

        historyWidget.command = "";
      };
    };
  };
}
