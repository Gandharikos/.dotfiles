{
  config,
  lib,
  aiCommon,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.my.agy;
  mcpModuleEnabled = config.my.mcp.enable or false;

  sharedAiTools = aiCommon;
in
{
  imports = [
    ./rules.nix
  ];

  options.my.agy = {
    enable = mkEnableOption "agy";
  };

  config = mkIf cfg.enable {
    programs.antigravity-cli = {
      enable = true;
      enableMcpIntegration = mcpModuleEnabled;

      settings = {
        context = {
          fileName = [
            "AGENTS.md"
            "GEMINI.md"
          ];
          discoveryMaxDirs = 1000;
          memoryBoundaryMarkers = [
            ".git"
            ".jj"
          ];
          # NOTE: bombs out on repos that don't have them
          # includeDirectories = [
          #   "lib"
          #   "modules"
          #   "docs"
          # ];
          loadMemoryFromIncludeDirectories = true;
          fileFiltering = {
            enableFuzzySearch = true;
            enableRecursiveFileSearch = true;
            respectGeminiIgnore = true;
            respectGitIgnore = true;
          };
        };

        experimental = {
          contextManagement = true;
          directWebFetch = true;
          memoryManager = true;
          modelSteering = true;
          taskTracker = true;
          topicUpdateNarration = true;
          useOSC52Copy = true;
          useOSC52Paste = true;
          worktrees = true;
        };

        advanced = {
          autoConfigureMemory = true;
        };

        general = {
          checkpointing.enabled = true;
          enableNotifications = true;
          preferredEditor = "neovim";
          sessionRetention = {
            enabled = true;
            maxAge = "30d";
            maxCount = 100;
          };
          vimMode = true;
          plan = {
            enabled = true;
            modelRouting = true;
          };
        };

        ide.enabled = true;

        privacy.usageStatisticsEnabled = false;

        security = {
          auth.selectedType = "oauth-personal";
          enablePermanentToolApproval = true;
          folderTrust.enabled = true;
          environmentVariableRedaction.enabled = true;
        };

        tools = {
          shell.showColor = true;
          useRipgrep = true;
          truncateToolOutputThreshold = 50000;
        };

        ui = {
          compactToolOutput = true;
          dynamicWindowTitle = true;
          footer = {
            hideContextPercentage = false;
            hideSandboxStatus = true;
          };
          inlineThinkingMode = "full";
          loadingPhrases = "tips";
          showCitations = true;
          showMemoryUsage = true;
          showModelInfoInChat = true;
          showStatusInTitle = true;
          showUserIdentity = false;
          theme = mkDefault "GitHub";
          useAlternateBuffer = true;
        };
      };

      context = {
        AGENTS = sharedAiTools.base;
      };

      commands = sharedAiTools.antigravityCli.commands // sharedAiTools.antigravityCli.agents;
    };
  };
}
