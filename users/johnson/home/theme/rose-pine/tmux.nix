{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules)
    mkAfter
    mkBefore
    mkDefault
    mkIf
    mkMerge
    ;
  cfg = config.nixporn.colorschemes.rose-pine;
  inherit (cfg) palette;
  enable = config.nixporn.colorscheme == "rose-pine" && config.my.tmux.enable;
  transparent = config.nixporn.transparent;
  plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "rose-pine";
    version = "unstable";
    rtpFilePath = "rose-pine.tmux";
    src = pkgs.nixporn.rose-pine.tmux;
  };
  windowFormat = "#I  #W#{?window_zoomed_flag, 󰁌,}";
in
{
  config = mkIf enable {
    nixporn.tmux.enable = mkDefault false;

    programs.tmux.plugins = mkMerge [
      (mkBefore [
        {
          plugin = pkgs.tmuxPlugins.tmux-window-name;
          extraConfig = ''
            set -g @tmux_window_name_max_name_len "20"
            set -g @tmux_window_name_dir_programs "['${lib.getExe config.programs.neovim.finalPackage.unwrapped}', '${lib.getExe pkgs.git}']"
            set -g @tmux_window_name_substitute_sets '[("^/nix/store/[^/]+/bin/(nvim|codex)(?: .*)?$", "\\g<1>"), ("^/nix/store/[^/]+/bin/", "")]'
          '';
        }
      ])
      [
        {
          inherit plugin;
          extraConfig = ''
            set -g @rose_pine_variant "${cfg.variant}"
            set -g @rose_pine_user "on"
            set -g @rose_pine_host "on"
            set -g @rose_pine_hostname_short "on"
            set -g @rose_pine_date_time "%Y-%m-%d %H:%M"
            set -g @rose_pine_directory "on"
            set -g @rose_pine_bar_bg_disable "${if transparent then "on" else "off"}"
            set -g @rose_pine_bar_bg_disabled_color_option "default"
            set -g @rose_pine_status_left_prepend_section '#{?client_prefix,#[fg=${palette.gold}]WAIT ,#{?pane_in_mode,#[fg=${palette.pine}]COPY ,#{?pane_synchronized,#[fg=${palette.iris}]SYNC ,}}}'
          '';
        }
      ]
    ];

    programs.tmux.extraConfig = mkAfter ''
      setw -g window-status-format "${windowFormat}"
      setw -g window-status-current-format "[${windowFormat}]"
    '';
  };
}
