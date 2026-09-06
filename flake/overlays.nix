# Credit to khaneliman
# https://github.com/khaneliman/khanelinix/blob/e971d9750b5e61e1f4ae18d63578bf169dd7ce68/flake/overlays.nix
{
  inputs,
  lib,
  ...
}:
let
  overlaysPath = ../overlays;
  dynamicOverlaysSet =
    if builtins.pathExists overlaysPath then
      lib.foldl' (
        acc: name:
        let
          overlayPath = overlaysPath + "/${name}";
          overlayValue = import overlayPath;
          resolved = if lib.isFunction overlayValue then overlayValue { inherit inputs; } else overlayValue;
          isOverlaySet =
            lib.isAttrs resolved && resolved != { } && lib.all lib.isFunction (builtins.attrValues resolved);
        in
        if isOverlaySet then acc // resolved else acc // { ${name} = resolved; }
      ) { } (builtins.attrNames (builtins.readDir overlaysPath))
    else
      { };

  dotPackagesOverlay =
    final: prev:
    let
      directory = ../packages;
      packageFunctions = prev.lib.filesystem.packagesFromDirectoryRecursive {
        inherit directory;
        callPackage = file: _args: import file;
      };
    in
    {
      dot = prev.lib.fix (
        self:
        prev.lib.mapAttrs (
          _name: func: final.callPackage func (self // { inherit inputs; })
        ) packageFunctions
      );
    };
in
{
  flake = {
    overlays = dynamicOverlaysSet // {
      default = dotPackagesOverlay;
      dot = dotPackagesOverlay;
      helium-browser = inputs.helium-browser.overlays.default;
      nixporn = inputs.nixporn.overlays.default;
      omniwm = inputs.omniwm.overlays.default;
    };
  };
}
