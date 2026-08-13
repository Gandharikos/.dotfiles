{
  config,
  pkgs,
  lib,
  aiCommon,
  ...
}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) optionalAttrs;
  cfg = config.my.claude-code;
  hooks = lib.dot.importDir ./hooks {
    inherit
      config
      pkgs
      ;
  };
  mcpModuleEnabled = config.my.mcp.enable or false;
  headroomEnabled = config.my.headroom.enable or false;
  sharedAiTools = aiCommon;
  claudeIcon = ./assets/claude.ico;
in
{
  imports = [
    ./permissions.nix
  ];

  options.my.claude-code = {
    enable = mkEnableOption "claude-code";
  };

  config = mkIf cfg.enable {
    # Install Claude icon for notifications
    xdg.dataFile."icons/claude.ico".source = claudeIcon;

    programs.claude-code = {
      enable = true;
      enableMcpIntegration = mcpModuleEnabled;

      plugins = {
        claude-code-wakatime = pkgs.fetchFromGitHub {
          owner = "wakatime";
          repo = "claude-code-wakatime";
          rev = "v3.1.6";
          sha256 = "14qym1qjli6k9andgjk1a4wdj5wf5apfw7dis6v1pa73xl4w6ybm";
        };
      };

      settings = {
        theme = "dark";
        inherit hooks;
        verbose = true;
        includeCoAuthoredBy = false;

        gitAttribution = false;
        statusLine = {
          type = "command";
          command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
          padding = 0;
        };
        attribution = {
          commit = "";
          pr = "";
        };

        env = {
          USE_BUILTIN_RIPGREP = "0";
        }
        // optionalAttrs mcpModuleEnabled {
          ENABLE_TOOL_SEARCH = "auto:5";
        }
        // optionalAttrs headroomEnabled {
          # Route Claude Code through the local Headroom proxy for token compression.
          ANTHROPIC_BASE_URL = config.my.headroom.baseUrl;
        };
      };

      inherit (sharedAiTools.claudeCode) agents commands;
      context = sharedAiTools.base;
    };
  };
}
