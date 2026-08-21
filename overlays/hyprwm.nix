{ inputs, ... }:
{
  hyprwm = inputs.nixpkgs.lib.composeManyExtensions [
    inputs.hyprland.overlays.hyprland-packages
    inputs.hyprland.overlays.hyprland-extras
    inputs.hypridle.overlays.hypridle
    (_final: prev: {
      hyprlandPlugins = prev.hyprlandPlugins // {
        hypr-dynamic-cursors = prev.hyprlandPlugins.hypr-dynamic-cursors.overrideAttrs (_: {
          version = "0-unstable-${inputs.hypr-dynamic-cursors.shortRev or "dirty"}";
          src = inputs.hypr-dynamic-cursors;
        });
      };
    })
  ];
}
