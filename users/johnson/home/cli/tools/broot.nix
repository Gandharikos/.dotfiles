{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.broot;
  editor = config.my.editor;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optionals;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  options.my.broot = {
    enable = mkEnableOption "broot";
  };

  config = mkIf cfg.enable {
    programs.broot = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;

      settings = {
        modal = true;
        initial_mode = "input";
        icon_theme = "nerdfont";
        default_flags = "-gh";
        show_selection_mark = true;
        lines_before_match_in_preview = 2;
        lines_after_match_in_preview = 2;
        capture_mouse = true;
        quit_on_last_cancel = false;
        verbs = [
          {
            invocation = "edit";
            shortcut = "e";
            key = "enter";
            apply_to = "text_file";
            external = "${editor} {file:space-separated}";
            leave_broot = false;
          }
          {
            invocation = "create {subpath}";
            execution = "${editor} {directory}/{subpath}";
            leave_broot = false;
          }
          {
            invocation = "git_diff";
            shortcut = "gd";
            leave_broot = false;
            execution = "git difftool -y {file}";
          }
          {
            invocation = "backup {version}";
            key = "ctrl-b";
            leave_broot = false;
            auto_exec = false;
            execution = "cp -r {file} {parent}/{file-stem}-{version}{file-dot-extension}";
          }
          {
            invocation = "terminal";
            key = "ctrl-t";
            execution = "$SHELL";
            set_working_dir = true;
            leave_broot = false;
          }
        ];
        preview_transformers = [
          {
            input_extensions = [ "json" ];
            output_extension = "json";
            mode = "text";
            command = [ "${lib.getExe' pkgs.jaq "jaq"}" ];
          }
          {
            input_extensions = [ "pdf" ];
            output_extension = "png";
            mode = "image";
            command = [
              "${lib.getExe' pkgs.mupdf "mutool"}"
              "draw"
              "-w"
              "1000"
              "-o"
              "{output-path}"
              "{input-path}"
            ];
          }
        ]
        ++ optionals isLinux [
          {
            input_extensions = [ "d2" ];
            output_extension = "png";
            mode = "image";
            command = [
              "${lib.getExe' pkgs.d2 "d2"}"
              "{input-path}"
              "{output-path}"
            ];
          }
        ];
      };
    };
  };
}
