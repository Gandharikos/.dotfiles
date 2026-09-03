{ lib, pkgs, ... }:
{
  dot = {
    primaryUser = "johnson";

    users.johnson.shell = lib.mkForce "bash";

    device = {
      type = "vm";
      cpu = null;
    };

    kernel.packages = pkgs.linuxPackages;

    yubikey.enable = false;

    services = {
      fail2ban.enable = false;
      zfs.enable = false;
    };
  };

  home-manager.users = lib.mkForce { };

  console.enable = lib.mkForce false;

  services = {
    userborn.enable = lib.mkForce false;
    fast-nix-gc = {
      enable = lib.mkForce false;
      automatic = lib.mkForce false;
    };
    fast-nix-optimise = {
      enable = lib.mkForce false;
      automatic = lib.mkForce false;
    };
  };

  security.account-utils.enable = lib.mkForce false;

  boot.kernelParams = lib.mkForce [
    "8250.nr_uarts=1"
    "boot.panic_on_fail"
    "loglevel=3"
    "lsm=landlock,yama,bpf"
    "nohibernate"
    "panic=1"
    "pti=on"
    "root=fstab"
  ];

  boot.kernel.sysctl = {
    # This VM is intentionally permissive for eBPF learning and tracing.
    "kernel.ftrace_enabled" = lib.mkForce true;
    "kernel.kptr_restrict" = lib.mkForce 0;
    "kernel.perf_event_paranoid" = lib.mkForce 1;
    "kernel.unprivileged_bpf_disabled" = lib.mkForce false;
    "net.core.bpf_jit_enable" = lib.mkForce true;
    "net.core.bpf_jit_harden" = lib.mkForce 0;
  };

  networking = {
    networkmanager.enable = lib.mkForce false;
    useNetworkd = true;
  };

  systemd.network.networks."10-microvm" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
  };

  nix.enable = false;

  programs = {
    fish.enable = lib.mkForce false;
    zsh.enable = lib.mkForce false;
  };

  system = {
    nixos-init.enable = lib.mkForce false;
    etc.overlay.enable = lib.mkForce false;
    switch.enable = false;
  };

  environment.systemPackages = lib.mkForce (
    with pkgs;
    [
      bpftools
      bpftrace
      clang
      curl
      elfutils
      gcc
      git
      gnumake
      jq
      libbpf
      llvmPackages.clang-tools
      perf
      pkg-config
      zlib
    ]
  );

  system.stateVersion = "26.11";
}
