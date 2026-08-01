{
  config,
  lib,
  ...
}:
{
  imports = lib.dot.scanPaths ./.;

  config = lib.mkIf config.dot.gui.desktop.wayland.enable {
    hardware.brillo.enable = true;
    users.groups.video.members = config.dot.enabledUsers;
  };
}
