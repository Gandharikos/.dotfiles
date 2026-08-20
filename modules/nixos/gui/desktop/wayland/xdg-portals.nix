{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.dot.gui.desktop;
  isNiri = cfg.default == "niri";
  portal =
    if cfg.default == "hyprland" then
      "hyprland"
    else if isNiri then
      "gnome"
    else
      "wlr";
  extraPortals =
    if isNiri then [ pkgs.xdg-desktop-portal-gnome ] else [ pkgs.xdg-desktop-portal-wlr ];
  wlrEnable = !isNiri;
  inherit (cfg.wayland) enable;
in
{
  config = mkIf enable {
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      inherit extraPortals;
      config.common = {
        default = "*";

        # for flameshot to work
        # https://github.com/flameshot-org/flameshot/issues/3363#issuecomment-1753771427
        "org.freedesktop.impl.portal.Screencast" = [ "${portal}" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "${portal}" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      wlr = {
        enable = mkDefault wlrEnable;
        settings = {
          screencast = {
            max_fps = 60;
            chooser_type = "simple";
            chooser_cmd = "${getExe pkgs.slurp} -f %o -or";
          };
        };
      };
    };

    # xdg-desktop-portal-gnome refuses to expose ScreenCast/Screenshot on non-GNOME
    # compositors when GDK_BACKEND is set (reports "GDK backend forced via env var,
    # Non-compatible display server, exposing settings only").
    # Unset it so the portal can auto-detect and work correctly under Niri.
    systemd.user.services.xdg-desktop-portal-gnome = mkIf isNiri {
      serviceConfig.UnsetEnvironment = [ "GDK_BACKEND" ];
    };
  };
}
