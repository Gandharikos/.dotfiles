{ inputs, ... }:
{
  ai =
    final: _prev:
    let
      system = final.stdenv.hostPlatform.system;
      llmAgentPackages = inputs.llm-agents.packages.${system};
    in
    {
      inherit (llmAgentPackages)
        claude-desktop
        cursor-agent
        qwen-code
        hermes-desktop
        hermes-hud
        copilot-cli
        chatgpt
        ;
    };
}
