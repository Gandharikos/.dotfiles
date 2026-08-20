# XDG stands for "Cross-Desktop Group", with X used to mean "cross".
# It's a bunch of specifications from freedesktop.org intended to standardize desktops and
# other GUI applications on various systems (primarily Unix-like) to be interoperable:
#   https://www.freedesktop.org/wiki/Specifications/
{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  inherit (config) my;
  home = config.home.homeDirectory;
  editorDesktopId = "${if (my.editor or "helix") == "helix" then "Helix" else my.editor}.desktop";
  browserDesktopId = my.gui.browser.desktopId or null;
  # define default applications for some url schemes.
  browser = [
    # keep-sorted start
    "application/rdf+xml"
    "application/rss+xml"
    "application/x-extension-htm"
    "application/x-extension-html"
    "application/x-extension-shtml"
    "application/x-extension-xht"
    "application/x-extension-xhtml"
    "application/xhtml+xml"
    "application/xhtml_xml"
    "application/xml"
    "text/html"
    "text/xml"
    "x-scheme-handler/about" # open `about:` url with `browser`
    "x-scheme-handler/ftp" # open `ftp:` url with `browser`
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/unknown"
    # keep-sorted end
  ];
  editor = [
    # keep-sorted start
    "application/json"
    "application/x-shellscript"
    "text/english"
    "text/plain"
    "text/x-c"
    "text/x-c++"
    "text/x-c++hdr"
    "text/x-c++src"
    "text/x-chdr"
    "text/x-csrc"
    "text/x-java"
    "text/x-makefile"
    "text/x-moc"
    "text/x-pascal"
    "text/x-tcl"
    "text/x-tex"
    # keep-sorted end
  ];
  media = [
    "video/*"
    "audio/*"
  ];

  images = [ "image/*" ];
  associations =
    (lib.genAttrs editor (_: [ editorDesktopId ]))
    // (lib.genAttrs media (_: [ "mpv.desktop" ]))
    // (lib.genAttrs images (_: [ "viewnior.desktop" ]))
    // (lib.optionalAttrs (browserDesktopId != null) (lib.genAttrs browser (_: [ browserDesktopId ])))
    // {
      "application/pdf" = [ "org.pwmt.zathura.desktop" ];
      "x-scheme-handler/discord" = [ "Discord.desktop" ];
      "x-scheme-handler/slack" = [ "slack.desktop" ];
      "x-scheme-handler/spotify" = [ "spotify.desktop" ];
      "x-scheme-handler/tg" = [ "org.telegram.desktop" ];
      "x-scheme-handler/tonsite" = [ "org.telegram.desktop" ];
      "inode/directory" = [ "thunar.desktop" ];
    };
in
{
  # xdg.configFile."mimeapps.list".force = true;
  xdg = {
    enable = true;

    cacheHome = "${home}/.cache";
    configHome = "${home}/.config";
    dataHome = "${home}/.local/share";
    stateHome = "${home}/.local/state";

    userDirs = mkIf isLinux {
      enable = true;
      createDirectories = true;

      # keep-sorted start
      desktop = "${home}/Desktop";
      documents = "${home}/Documents";
      download = "${home}/Downloads";
      music = "${home}/Media/Music";
      pictures = "${home}/Media/Pictures";
      publicShare = "${home}/Public/Share";
      templates = "${home}/Public/Templates";
      videos = "${home}/Media/Videos";
      # keep-sorted end
      extraConfig = {
        # keep-sorted start
        DEV = "${home}/Dev";
        MISC = "''${home}/Misc";
        NOTES = "${config.xdg.userDirs.documents}/Notes";
        PROJECTS = "${home}/Dev/Projects";
        RECORDINGS = "${config.xdg.userDirs.videos}/Recorder";
        REPOS = "${home}/Dev/Repos";
        SCREENSHOTS = "${config.xdg.userDirs.pictures}/Screenshots";
        SECRET = "${home}/.secrets";
        WALLPAPERS = "${config.xdg.userDirs.pictures}/Wallpapers";
        WORKSPACES = "${home}/Dev/Workspaces";
        # keep-sorted end
      };
    };

    # manage $XDG_CONFIG_HOME/mimeapps.list
    # xdg search all desktop entries from $XDG_DATA_DIRS, check it by command:
    #  echo $XDG_DATA_DIRS
    # the system-level desktop entries can be list by command:
    #   ls -l /run/current-system/sw/share/applications/
    # the user-level desktop entries can be list by command(user ryan):
    #  ls /etc/profiles/per-user/ryan/share/applications/
    mimeApps = mkIf (osConfig.dot.gui.enable && isLinux) {
      enable = true;
      # let `xdg-open` to open the url with the correct application.
      defaultApplications = associations;
      associations.added = associations;
    };
  };

  home.activation.createXdgExtraDirs = mkIf isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ${lib.escapeShellArg config.xdg.userDirs.extraConfig.RECORDINGS}
    ''
  );
}
