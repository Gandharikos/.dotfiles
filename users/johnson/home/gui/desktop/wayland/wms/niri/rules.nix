{
  inputs,
  lib,
  config,
  options,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.lists) singleton;
  browserAppIds = [
    "zen"
    "firefox"
    "org.mozilla.firefox"
    "helium"
    "chromium"
    "chromium-browser"
    "google-chrome"
    "google-chrome-stable"
  ];
  browserMatches = builtins.map (appId: { "app-id" = "^${appId}$"; }) browserAppIds;
  ghosttyAppId = "^com\\.mitchellh\\.ghostty$";
  pipTitle = "^(Picture-in-Picture|Picture in picture)$";
  passwordManagerAppId = "^(Bitwarden|chrome-nngceckbapebfimnlniiiahkandclblb-Default)$";
  passwordManagerTitle = "^(1Password|Bitwarden|.*[Vv]aultwarden.*)$";
  passwordManagerMatches = [
    { title = passwordManagerTitle; }
    { "app-id" = passwordManagerAppId; }
  ];
  spotifyMatches = [
    { "app-id" = "^(Spotify|spotify)$"; }
    { title = "^(Spotify( Premium)?)$"; }
  ];
  # niri-flake does not expose the 26.04 background-effect block yet.
  ghosttyBlurRule =
    with inputs.niri.lib.kdl;
    (node "window-rule"
      [ ]
      [
        (leaf "match" { "app-id" = ghosttyAppId; })
        (node "background-effect"
          [ ]
          [
            (leaf "blur" true)
            (leaf "xray" false)
          ]
        )
      ]
    );
  cfg = config.my.gui.desktop.niri;
in
{
  config = mkIf cfg.enable {
    programs.niri = {
      config = options.programs.niri.config.default ++ [ ghosttyBlurRule ];
      settings = {
        layer-rules = [
          {
            matches = singleton { namespace = "^noctalia-backdrop$"; };
            place-within-backdrop = true;
          }
        ];
        window-rules = [
          {
            geometry-corner-radius = {
              top-left = 20.0;
              top-right = 20.0;
              bottom-left = 20.0;
              bottom-right = 20.0;
            };
            clip-to-geometry = true;
            draw-border-with-background = false;
          }
          {
            matches = passwordManagerMatches;
            open-floating = true;
          }
          {
            matches = browserMatches;
            excludes = [ { title = pipTitle; } ] ++ passwordManagerMatches;
            open-maximized = true;
          }
          {
            matches = singleton { title = pipTitle; };
            open-floating = true;
            open-focused = false;
            default-floating-position = {
              x = 24;
              y = 24;
              relative-to = "bottom-right";
            };
            default-column-width = {
              proportion = 0.3;
            };
            default-window-height = {
              proportion = 0.3;
            };
          }
          {
            matches = spotifyMatches;
            open-on-workspace = "9";
          }
          {
            matches = singleton { is-floating = true; };
            border.enable = false;
          }
          {
            matches = spotifyMatches;
            opacity = 0.85;
          }
          {
            matches = singleton { "app-id" = "^(dev\\.zed\\.Zed|zed)$"; };
            opacity = 0.88;
          }
        ];
      };
    };
  };
}
