{
  inputs,
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (config.my.gui) desktop;
  inherit (osConfig.dot.keyboard) keys;
  inherit (config.nixporn)
    avatar
    wallpaper
    ;

  enable = osConfig.dot.gui.desktop.wayland.enable && desktop.shell.default == "noctalia";
  wallpaperDirectory =
    if wallpaper == null then "~/Pictures/Wallpapers" else builtins.dirOf (toString wallpaper);
  baseSettings = import ./settings.nix {
    inherit
      inputs
      config
      osConfig
      keys
      lib
      avatar
      wallpaper
      wallpaperDirectory
      ;
  };
in
{
  imports = [
    inputs.noctalia.homeModules.default
    ./bindings.nix
  ];

  config = mkIf enable {
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
      settings = baseSettings;
    };

    # UWSM intentionally keeps session-specific variables such as XDG_SESSION_ID
    # out of the systemd user manager environment because they belong to one login
    # session. Noctalia runs as a user service, so its GetSessionByPID fallback sees
    # the manager session instead and cannot subscribe to the graphical session's
    # logind Lock/Unlock signals. Import UWSM's per-session environment file so
    # commands such as Vicinae's `Lock Session` reach Noctalia's lock screen.
    systemd.user.services.noctalia.Service = lib.mkIf osConfig.dot.gui.desktop.uwsm.enable {
      EnvironmentFile = "%t/uwsm/env_session.conf";
    };

    home.packages = [
      pkgs.evtest
    ];
  };
}
