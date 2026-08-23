{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;
  inherit (lib.lists) optionals;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  claudeEnabled = config.my.claude-code.enable or false;
  codexEnabled = config.my.codex.enable or false;
  hermesEnabled = osConfig.dot.services.hermes-agent.enable or false;
in
{
  config = mkIf (osConfig.dot.gui.enable && isLinux) {
    home.packages =
      with pkgs;
      optionals claudeEnabled [ claude-desktop ]
      ++ optionals codexEnabled [ chatgpt ]
      ++ optionals hermesEnabled [ hermes-desktop ];

    xdg.desktopEntries.hermes-desktop = mkIf hermesEnabled {
      name = "Hermes Desktop";
      genericName = "AI agent desktop";
      comment = "Native Electron desktop shell for Hermes Agent";
      exec = "${lib.getExe pkgs.hermes-desktop}";
      icon = "${pkgs.hermes-desktop}/share/hermes-desktop/dist/hermes.png";
      terminal = false;
      categories = [
        "Development"
        "Utility"
      ];
    };
  };
}
