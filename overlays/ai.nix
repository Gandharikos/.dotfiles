{ inputs, ... }:
{
  ai =
    final: _prev:
    let
      system = final.stdenv.hostPlatform.system;
      llmAgentPackages = inputs.llm-agents.packages.${system};
      hermesDesktopElectronHeadersHash = "sha256-f8bSbLRmtbP93CJAvEBs+sHWDZ1xP2bcpLhC1EnOmZU=";
      hermesDesktopPkgs = final // {
        fetchurl =
          args:
          final.fetchurl (
            args
            //
              final.lib.optionalAttrs
                (args.url == "https://artifacts.electronjs.org/headers/dist/v41.10.3/node-v41.10.3-headers.tar.gz")
                {
                  sha256 = hermesDesktopElectronHeadersHash;
                }
          );
      };
    in
    {
      inherit (llmAgentPackages)
        claude-desktop
        cursor-agent
        qwen-code
        ;

      github-copilot-cli = llmAgentPackages.copilot-cli;
      codex-desktop = inputs.codex-desktop-linux.packages.${system}.codex-desktop;
      hermes-desktop = inputs.hermes-agent.packages.${system}.desktop.override {
        pkgs = hermesDesktopPkgs;
      };
      inherit (llmAgentPackages) hermes-hud;
    };

  zz-ai-python-fixes = _final: prev: {
    pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
      (_pythonFinal: pythonPrev: {
        catppuccin = pythonPrev.catppuccin.overridePythonAttrs (old: {
          # catppuccin 2.5.0 still imports matplotlib.style.core during the
          # test/import checks, which is gone in newer matplotlib.
          doCheck = false;
          pythonImportsCheck = builtins.filter (module: module != "catppuccin") (
            old.pythonImportsCheck or [ ]
          );
        });
      })
    ];
  };
}
