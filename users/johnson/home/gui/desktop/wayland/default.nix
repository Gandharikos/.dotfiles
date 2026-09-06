{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  inherit (lib.modules) mkIf;
in
{
  imports = lib.dot.scanPaths ./.;

  config = mkIf osConfig.dot.gui.desktop.wayland.enable {
    home.packages = with pkgs; [
      # keep-sorted start
      avizo
      brightnessctl
      brillo
      ffmpeg
      gifski # GIF encoder
      glib
      gnome-characters
      gnome-connections
      gnome-console
      gnome-font-viewer
      gnome-maps
      gnome-shell-extensions
      gnome-tour
      gpu-screen-recorder # GPU-accelerated screen recorder
      grim
      imagemagick # Image manipulation
      loupe
      playerctl
      slurp
      tesseract5
      translate-shell # Translation tool
      # use more uwsm wrappers
      uwsm
      wf-recorder
      wireplumber
      wl-clipboard-rs
      wlr-randr
      zbar # Barcode/QR code reader
      # keep-sorted end
    ];
  };
}
