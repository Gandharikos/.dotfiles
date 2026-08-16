{
  pkgs,
  inputs,
  ...
}:
let
  primaryUser = "johnson";
in
{
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    (import ../common/disko/luks-btrfs-tmpfs.nix { })
  ];
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      # Keep the installer from taking boot priority over the target system.
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot";
    };
  };
  users.users.root.password = "123456";
  users.users.${primaryUser} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    password = "123456";
  };
  # ssh-agent is used to pull my private secrets repo from github when deploying my nixos config.
  programs.ssh.startAgent = true;

  # Enable SSH server for remote installation
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
    openFirewall = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    git
    gnumake
    wget
    just # a command runner(replacement of gnumake in some cases)
    curl
  ];
  networking = {
    # configures the network interface(include wireless) via `nmcli` & `nmtui`
    networkmanager.enable = true;
  };
  system.stateVersion = "25.11";
}
