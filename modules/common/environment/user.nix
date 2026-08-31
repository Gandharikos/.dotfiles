{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.dot) enabledUsers users;
  inherit (lib.attrsets) genAttrs;
in
{
  environment = {
    # add user's shell into /etc/shells
    shells = with pkgs; [
      bash
      fish
      nushell
      zsh
    ];
  };

  programs = {
    fish.enable = true;
    zsh.enable = true;
  };

  # Define a user account.
  users.users = genAttrs enabledUsers (name: {
    # https://github.com/LnL7/nix-darwin/issues/1237 still have a bug
    shell = builtins.getAttr users.${name}.shell pkgs;
    home = users.${name}.homeDirectory;
    description = name;
    openssh.authorizedKeys.keys = users.${name}.authorizedKeys;
  });
}
