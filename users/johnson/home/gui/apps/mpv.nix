{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  cfg = config.my.gui.apps.mpv;
  enable = osConfig.dot.gui.enable && cfg.enable;

  yt-dlp =
    (pkgs.yt-dlp.override {
      jsRuntime = pkgs.nodejs;
    }).overrideAttrs
      (prevAttrs: {
        makeWrapperArgs = (prevAttrs.makeWrapperArgs or [ ]) ++ [
          "--add-flag"
          "--js-runtimes=node"
        ];
      });

  homeDirectory = config.home.homeDirectory;
  musicDirectory = if isLinux then config.xdg.userDirs.music else "${homeDirectory}/Music";
  screenshotDirectory =
    if isLinux then
      config.xdg.userDirs.extraConfig.SCREENSHOTS
    else
      "${homeDirectory}/Pictures/Screenshots";
  videosDirectory = if isLinux then config.xdg.userDirs.videos else "${homeDirectory}/Movies";
in
{
  options.my.gui.apps.mpv = {
    enable = mkEnableOption "support for mpv" // {
      default = isLinux;
    };
  };

  config = mkIf enable {
    home.packages = [ yt-dlp ];

    programs.mpv = {
      enable = true;

      package = pkgs.mpv.override {
        inherit yt-dlp;

        scripts =
          (with pkgs.mpvScripts; [
            sponsorblock

            (videoclip.override { wl-clipboard = pkgs.wl-clipboard-rs; })

            modernz
            thumbfast

            mpv-image-viewer.image-positioning
            mpvacious
          ])
          ++ lib.optionals isLinux [ pkgs.mpvScripts.mpris ];
      };

      bindings = {
        "AXIS_UP" = "add volume 2";
        "AXIS_DOWN" = "add volume -2";
        "UP" = "add volume 2";
        "DOWN" = "add volume -2";
        "Shift+RIGHT" = "frame-step";
        "Shift+LEFT" = "frame-back-step";
        "Shift+UP" = "add volume 10";
        "Shift+DOWN" = "add volume -10";
        "y" = "cycle deband";
        "z" = "cycle deband";
        "ctrl+d" = "vf toggle yadif";
        "e" = "add sub-delay +0.042";
        "w" = "add sub-delay -0.042";
        "b" = "add audio-delay +0.042";
        "n" = "add audio-delay -0.042";
        "Shift+a" = "cycle-values video-aspect \"16:9\" \"4:3\" \"2.35:1\" \"-1\"";

        "c" = "script-binding videoclip-menu-open";

        MBTN_RIGHT = "script-binding drag-to-pan";
        "alt+down" = "repeatable script-message pan-image y -0.01 yes yes";
        "alt+up" = "repeatable script-message pan-image y +0.01 yes yes";
        "alt+right" = "repeatable script-message pan-image x -0.01 yes yes";
        "alt+left" = "repeatable script-message pan-image x +0.01 yes yes";
      };

      config = {
        osc = "no";
        border = "no";
        msg-color = "yes";
        msg-module = "yes";

        save-watch-history = "yes";

        volume-max = 200;

        hwdec = if isLinux then "auto-copy" else "auto";
        gpu-api = if isLinux then "vulkan" else "auto";
        profile = "gpu-hq";
        vo = "gpu-next";

        screenshot-directory = screenshotDirectory;
        screenshot-template = "%x/screenshot-%F-T%wH.%wM.%wS.%wT-F%{estimated-frame-number}";
        screenshot-format = "png";
        screenshot-png-compression = 4;
        screenshot-tag-colorspace = "yes";
        screenshot-high-bit-depth = "yes";

        alang = "en,zh,zho,chi,jpn,jp";

        stop-screensaver = "yes";
        cursor-autohide = 100;
        reset-on-next-file = "video-zoom,panscan,video-unscaled,video-rotate,video-align-x,video-align-y";
        watch-later-options-remove = "sub-pos";
      };

      profiles = {
        image = {
          profile-cond = ''p["current-tracks/video"] and p["current-tracks/video"].image and not p["current-tracks/video"].albumart'';
          profile-restore = "copy-equal";

          include = toString (
            pkgs.writeText "mpv-image-viewer.conf" ''
              script-opts-append=modernz-fade_alpha=50
              script-opts-append=modernz-window_title=yes
              script-opts-append=modernz-bottomhover_zone=50
            ''
          );

          title = "\${media-title} [\${?width:\${width}x\${height}}]";
          taskbar-progress = "no";
          video-unscaled = "yes";
          video-recenter = "yes";
          window-dragging = "no";

          prefetch-playlist = "yes";
          video-aspect-override = "no";

          loop-file = "inf";
          image-display-duration = "inf";
          loop-playlist = "inf";
        };

        video = {
          profile-cond = ''p["current-tracks/video"] and not p["current-tracks/video"].image'';
          profile-restore = "copy-equal";
          taskbar-progress = "yes";
        };
      };

      scriptOpts = {
        modernz = {
          idlescreen = "no";
          download_path = videosDirectory;

          ontop_button = "no";
          speed_button = "yes";
          info_button = "no";
          fullscreen_button = "no";

          hover_effect = "color";
          hover_effect_color = lib.mkForce "#74c7ec";
          seekbarfg_color = lib.mkForce "#74c7ec";
          seekbarbg_color = lib.mkForce "#181825";
          seek_handle_color = lib.mkForce "#74c7ec";
          seek_handle_border_color = lib.mkForce "#1e1e2e";
        };

        videoclip = {
          video_folder_path = "${videosDirectory}/Clips";
          audio_folder_path = "${musicDirectory}/Clips";
          video_quality = 10;
        };
      };
    };

    services.plex-mpv-shim.enable = true;
  };
}
