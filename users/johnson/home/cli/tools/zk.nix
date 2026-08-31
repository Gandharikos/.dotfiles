{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.my.zk;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.my.zk = {
    enable = mkEnableOption "zk";
  };
  config = mkIf cfg.enable {
    programs.zk = {
      enable = true;
      settings = {
        notebook.dir = "~/Documents/Notes";
        note = {
          language = "en";
          default-title = "Untitled";
          template = "default.md";
          filename = "{{id}}-{{slug title}}";
          extension = "md";
          # The charset used for random IDs. You can use:
          #   * letters: only letters from a to z.
          #   * numbers: 0 to 9
          #   * alphanum: letters + numbers
          #   * hex: hexadecimal, from a to f and 0 to 9
          #   * custom string: will use any character from the provided value
          id-charset = "hex";

          # Length of the generated IDs.
          id-length = 6;
        };

        format.markdown = {
          link-format = "wiki";
          # Enable support for :colon:separated:tags:.
          hashtags = true;
          # Enable support for :colon:separated:tags:.
          colon-tags = true;
          # Enable support for Bear's #multi-word tags#
          multiword-tags = true;
        };

        group = {
          daily = {
            # Directories listed here will automatically use this group when creating notes.
            paths = [ "Fleeting/Daily" ];
            note = {
              # %Y-%m-%d is actually the default format, so you could use {{format-date now}} instead.
              filename = "{{format-date now '%Y-%m-%d'}}";
              extension = "md";
              template = "daily.md";
            };
          };
        };

        # Need to specify the theme or else glow will not output color
        tool = {
          inherit (config.my) editor pager;
          # zk command aliases use POSIX syntax and cannot receive `nu -c` arguments.
          shell = if config.my.shell == "nushell" then lib.getExe pkgs.bash else config.my.shell;
          fzf-preview = "${lib.getExe pkgs.glow} --style ${config.home.sessionVariables.GLAMOUR_STYLE} {-1}";
        };

        alias =
          let
            # Respect the user's preferred shell when forwarding arguments.
            argsVar = if config.my.shell == "fish" then "$argv" else "$@";
          in
          {
            list = "zk list --quiet -f oneline ${argsVar}";
            ls = "zk list ${argsVar}";
            wc = "zk list --sort word-count ${argsVar}";

            search = "zk list -i ${argsVar}";

            # remove a files
            rm = "zk list --interactive --quiet --format path --delimiter0 ${argsVar} | xargs -0 rm -vf --";

            daily = "zk new $ZK_NOTEBOOK_DIR/Fleeting/Daily";

            # Show a random note.
            lucky = "zk list --quiet --format full --sort random --limit 1";

            # Edit the last modified note.
            last = "zk edit --limit 1 --sort modified- ${argsVar}";

            # Edit the notes selected interactively among the notes created the last two weeks.
            # This alias doesn't take any argument, so nothing to forward.
            recent = "zk edit --sort created- --created-after 'last two weeks' --interactive";

            # Print paths separated with colons for the notes found with the given
            # arguments. This can be useful to expand a complex search query into a flag
            # taking only paths. For example:
            #   zk list --link-to "`zk path -m potato`"
            path = "zk list --quiet --format {{path}} --delimiter , ${argsVar}";

            # Returns the Git history for the notes found with the given arguments.
            # Note the use of a pipe: we still forward the original arguments.
            log = "zk list --format path --delimiter0 --quiet ${argsVar} | xargs -t -0 git log --patch --";

            tags = "zk tag list ${argsVar}";
          };

        lsp = {
          diagnostics = {
            # Report titles of wiki-links as hints.
            wiki-title = "hint";
            # Warn for dead links between notes.
            dead-link = "error";
          };
          completion = {
            # Show the note title in the completion pop-up, or fallback on its path if empty.
            note-label = "{{title-or-path}}";
            # Filter out the completion pop-up using the note title or its path.
            note-filter-text = "{{title}} {{path}}";
            # Show the note filename without extension as detail.
            note-detail = "{{filename-stem}}";
          };
        };

        extra.author = config.my.name;
      };
    };
  };
}
