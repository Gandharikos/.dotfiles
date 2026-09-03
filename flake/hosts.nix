{
  self,
  inputs,
  lib,
  withSystem,
  ...
}:
{
  imports = [ inputs.flake-hosts.flakeModule ];

  config.flake-hosts = {
    auto = {
      enable = true;
      hostsDir = ../hosts;
    };
    perClass = class: {
      modules = [
        # import the class module, this contains the common configurations between all systems of the same class
        "${self}/modules/${class}/default.nix"
        "${self}/users/default.nix"
      ]
      ++ (
        if class == "nixos" then
          [
            inputs.home-manager.nixosModules.home-manager
            inputs.disko.nixosModules.disko
            # inputs.niri.nixosModules.niri
            inputs.sops.nixosModules.sops
          ]
        else if class == "darwin" then
          [
            inputs.home-manager.darwinModules.home-manager
            inputs.sops.darwinModules.sops
          ]
        else
          [ ]
      );
      specialArgs = {
        inherit
          lib
          self
          inputs
          withSystem
          ; # Pass all the args that your modules need
      };
    };
  };
}
