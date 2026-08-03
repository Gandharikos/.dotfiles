{
  config,
  aiCommon,
  lib,
  ...
}:
let
  cfg = config.my.pi;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.my.pi.enable = mkEnableOption "Pi coding agent configuration";

  config = mkIf cfg.enable {
    programs.pi-coding-agent = {
      enable = true;
      context = aiCommon.base;
      settings = {
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-sol";
        defaultThinkingLevel = "high";
        enableTelemetry = false;
        collapseChangelogs = true;
        transport = "auto";
        compaction = {
          reserveTokens = 20000;
          keepRecentTokens = 50000;
        };
        retry = {
          provider.maxRetryDelayMs = 60000;
        };
      };
    };
  };
}
