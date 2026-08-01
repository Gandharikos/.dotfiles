{ lib, osConfig, ... }:
let
  isMinimal = osConfig ? dot && osConfig.dot.profiles.minimal.enable or false;
in
{
  imports = lib.dot.scanPaths ./.;

  my = {
    # keep-sorted start block=yes newline_separated=yes
    _1password-cli = {
      enable = !isMinimal;
      enableSshSocket = !isMinimal;
    };

    agy.enable = !isMinimal;

    atuin = {
      enable = true;
      autoLogin = !isMinimal;
    };

    backups.taildrop = {
      enable = osConfig.networking.hostName == "ymir";
      schedule = "03:30";
    };

    bash.enable = true;

    bat.enable = true;

    bitwarden-cli.enable = !isMinimal;

    broot.enable = !isMinimal;

    brotab.enable = !isMinimal;

    btop.enable = true;

    carapace.enable = true;

    claude-code.enable = !isMinimal;

    codex = {
      enable = !isMinimal;
      useHeadroom = false;
    };

    direnv = {
      enable = true;
      silent = true;
    };

    eza.enable = true;

    fastfetch = {
      enable = true;
      startOnLogin = !isMinimal;
    };

    fd.enable = true;

    fzf.enable = true;

    gh.enable = !isMinimal;

    git.enable = true;

    github-copilot-cli.enable = !isMinimal;

    glow.enable = !isMinimal;

    gui.apps.anki.enable = !isMinimal;

    gui.apps.bitwarden.enable = !isMinimal;

    gui.apps.clash.enable = false;

    gui.apps.discord.enable = !isMinimal;

    gui.apps.slack.enable = !isMinimal;

    gui.apps.telegram.enable = !isMinimal;

    headroom.enable = !isMinimal;

    herdr.enable = !isMinimal;

    jjui.enable = !isMinimal;

    jujutsu.enable = !isMinimal;

    langs = {
      cc = {
        enable = true;
      };

      ebpf = {
        enable = true;
      };

      node = {
        enable = true;
      };

      python = {
        enable = true;
      };

      rust = {
        enable = true;
      };

      # r = {
      #   enable = true;
      # };
    };

    lazygit.enable = !isMinimal;

    mail.enable = !isMinimal;

    mcp.enable = !isMinimal;

    mux = {
      default = if isMinimal then null else "tmux";
      autoStart = !isMinimal;
    };

    navi.enable = !isMinimal;

    neovim = {
      enable = true;
      distro = if isMinimal then null else "lazyvim";
    };

    nix-index.enable = !isMinimal;

    nix-search-tv.enable = !isMinimal;

    nix-your-shell.enable = !isMinimal;

    numbat.enable = !isMinimal;

    opencode.enable = !isMinimal;

    pay-respects.enable = !isMinimal;

    pet.enable = !isMinimal;

    pi.enable = !isMinimal;

    polymarket.enable = !isMinimal;

    ripgrep.enable = true;

    security.gpg.enableSshSupport = osConfig.dot.yubikey.enable;

    ssh.gpgAgentForwarding = {
      enable = osConfig.dot.yubikey.enable;
      hosts = [ "ymir" ];
    };

    starship.enable = true;

    tealdeer.enable = !isMinimal;

    topgrade.enable = !isMinimal;

    typst.enable = !isMinimal;

    wakatime.enable = !isMinimal;

    yazi.enable = !isMinimal;

    zellij.enable = !isMinimal;

    zk.enable = !isMinimal;

    zoxide.enable = true;
    # keep-sorted end
  };
}
