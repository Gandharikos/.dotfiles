{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (lib.strings) optionalString;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  cfg = config.my.fish;
  isColemak = osConfig.dot.keyboard.layout == "colemak";
in
{
  options.my.fish = {
    enable = mkEnableOption "fish" // {
      default = config.my.shell == "fish";
    };
  };

  config = mkIf cfg.enable {
    programs.fish = {
      enable = true;
      plugins =
        let
          pluginNames = [
            "done"
            "forgit"
            "autopair"
            "sponge"
            "humantime-fish"
            "colored-man-pages"
            # "fish-you-should-use"
            "bang-bang"
            "bass"
          ]
          ++ optionals isDarwin [
            "macos"
          ];
        in
        map (name: {
          inherit name;
          inherit (pkgs.fishPlugins."${name}") src;
        }) pluginNames;
      interactiveShellInit = ''
        set -gx fish_vi_force_cursor 1
        set -gx fish_cursor_default block
        set -gx fish_cursor_insert line blink
        set -gx fish_cursor_visual block
        set -gx fish_cursor_replace_one underscore
        set -g fish_emoji_width 2
        set -g sponge_purge_only_on_exit true
        # Use fish for `nix develop`
        ${getExe pkgs.nix-your-shell} fish | source
      '';
      shellAbbrs = config.my.shellAbbrs;
      functions = {
        mkcd = {
          body = "mkdir -p $argv[1] && cd $argv[1]";
          description = "Create a directory and cd into it";
        };
        extract = {
          body = ''
            if test -f $argv[1]
                switch $argv[1]
                    case "*.tar.bz2"
                        tar xjf $argv[1]
                    case "*.tar.gz"
                        tar xzf $argv[1]
                    case "*.bz2"
                        bunzip2 $argv[1]
                    case "*.rar"
                        unrar x $argv[1]
                    case "*.gz"
                        gunzip $argv[1]
                    case "*.tar"
                        tar xf $argv[1]
                    case "*.tbz2"
                        tar xjf $argv[1]
                    case "*.tgz"
                        tar xzf $argv[1]
                    case "*.zip"
                        unar $argv[1]
                    case "*.Z"
                        uncompress $argv[1]
                    case "*.7z"
                        7z x $argv[1]
                    case "*.deb"
                        ar x $argv[1]
                    case "*.tar.xz"
                        tar xf $argv[1]
                    case "*.tar.zst"
                        tar xf $argv[1]
                    case '*'
                        echo "'$argv[1]' cannot be extracted using ex()"
                end
            else
                echo "'$argv[1]' is not a valid file"
            end
          '';
        };
        backup = {
          argumentNames = "filename";
          body = "cp $filename $filename.bak";
        };
        restore = {
          argumentNames = "filename";
          body = "mv $filename (echo $filename | sed s/.bak//)";
        };
        start = {
          body = ''
            set service_name $argv[1]

            # Start the service
            sudo systemctl start $service_name

            # Wait for the service to become active
            while true
                if systemctl is-active --quiet $service_name
                    break
                else
                    echo "Waiting for service to start..."
                    sleep 1
                end
            end

            # Optionally, show some of the recent logs for the service
            journalctl -u $service_name --no-pager -n 10
          '';
        };
        fish_user_key_bindings = {
          body = ''
            set -g fish_key_bindings fish_vi_key_bindings
            fish_default_key_bindings -M insert
            fish_vi_key_bindings --no-erase insert
            bind -M visual -m default y 'fish_clipboard_copy; commandline -f end-selection repaint-mode'
            bind yy fish_clipboard_copy
            bind p fish_clipboard_paste
          ''
          + optionalString isColemak ''
            bind N beginning-of-line
            bind O end-of-line
            bind I up-or-search
            bind E down-or-search
            bind o forward-char
            bind n backward-char
            bind i up-or-search
            bind e down-or-search
            bind E end-of-line delete-char
            bind I man\ \(commandline\ -t\)\ 2\>/dev/null\;\ or\ echo\ -n\ \\a
            bind j forward-single-char forward-word backward-char
            bind J forward-bigword backward-char
            bind k kill-line
            bind K kill-whole-line
            bind -m insert h repaint-mode
            bind -m insert H beginning-of-line repaint-mode
            bind -m insert l insert-line-under repaint-mode
            bind -m insert L insert-line-over repaint-mode
            bind -M visual n backward-char
            bind -M visual o forward-char
            bind -M visual e down-line
            bind -M visual i up-line
            bind -M visual j forward-word
            bind -M viusal J forward-bigword
            bind -M viusal l swap-selection-start-stop repaint-mode
          '';
        };
      };
    };
  };
}
