{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./asus-dialpad.nix
    inputs.vicinae.nixosModules.default
    (import ../common/disko/luks-btrfs-tmpfs.nix { })
  ];

  dot = {
    primaryUser = "johnson";
    users.johnson.shell = "nushell";
    security = {
      fixWebcam = true;
    };
    kernel.tweaks.enable = true;
    boot = {
      secureBoot = true;
      tmpOnTmpfs = false;
      # DISABLED: Potential conflict with NVIDIA/ASUS drivers
      plymouth.enable = false;

      initrd = {
        tweaks.enable = true;
        optimizeCompressor = true;
      };
    };
    services = {
      btrbk.enable = true;
      zram.enable = true;
      printing.enable = true;
      fwupd.enable = true;
      asus.enable = true;
      logind.powerKey = "ignore";
    };
    gui = {
      desktop.default = "niri";
      game.enable = true;
    };
    virtual.enable = true;
    persistence.enable = true;
    device = {
      type = "laptop";
      cpu = "amd";
      gpu = "nvidia";
      hasBluetooth = true;
      hasPrinter = false;
      hasTPM = true;
      # ethernetDevices = [ "wlp2s0" ]; # ymir wifi device
      monitors = [
        {
          name = "eDP-1";
          resolution = "preferred";
          position = "auto";
          scale = 2.0;
        }
      ];
    };
    keyboard = {
      layout = "qwerty";
      backend = "keyd";
    };
  };

  nixporn.colorscheme = "rose-pine";

  home-manager.sharedModules = [
    {
      my.gui.apps.chromium.vaapiDriver = "radeonsi";
      my.gui.desktop.idle.suspend.enable = false;
      programs.niri.settings.debug.render-drm-device = "/dev/dri/by-path/pci-0000:65:00.0-render";
    }
  ];
}
