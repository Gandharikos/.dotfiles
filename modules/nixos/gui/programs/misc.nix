{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.dot) gui;
  inherit (lib.modules) mkIf;
in
{
  config = mkIf gui.enable {
    environment.systemPackages = with pkgs; [
      android-tools
    ];

    programs = {
      chromium = {
        enable = true;
        defaultSearchProviderEnabled = true;
        defaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
        defaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";
        extraOpts = {
          DefaultSearchProviderName = "DuckDuckGo";
          DefaultSearchProviderKeyword = "ddg";
          DefaultSearchProviderIconURL = "https://duckduckgo.com/favicon.ico";
          DefaultSearchProviderEncodings = [ "UTF-8" ];
        };
      };

      # dconf is a low-level configuration system.
      # we neet it to interact with gtk
      dconf.enable = true;

      # gnome's keyring manager
      seahorse.enable = true;

      # show network usage
      bandwhich.enable = true;
    };
  };
}
