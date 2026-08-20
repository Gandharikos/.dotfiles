{
  config,
  osConfig,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  cfg = config.my.gui.apps.vscode;
  enable = osConfig.dot.gui.enable && cfg.enable;
in
{
  options.my.gui.apps.vscode = {
    enable = mkEnableOption "Visual Studio Code" // {
      default = true;
    };
  };

  config = mkIf enable {
    programs.vscodium = {
      enable = true;

      # Configure extensions, and let them be immutable.
      mutableExtensionsDir = false;
      profiles.default = {
        extensions =
          let
            pkgs' = pkgs.appendOverlays [ inputs.nix-vscode-extensions.overlays.default ];
            vscode = pkgs'.vscode-marketplace-release;
          in
          [
            vscode.anthropic.claude-code
            vscode.antfu.icons-carbon
            vscode.arrterian.nix-env-selector
            vscode.asvetliakov.vscode-neovim
            vscode.azemoh.one-monokai
            vscode.bbenoist.nix
            vscode.davidanson.vscode-markdownlint
            vscode.denoland.vscode-deno
            vscode.esbenp.prettier-vscode
            vscode.foxundermoon.shell-format
            vscode.github.copilot
            vscode.github.copilot-chat
            vscode.golang.go
            vscode.james-yu.latex-workshop
            vscode.llvm-vs-code-extensions.vscode-clangd
            vscode.ms-azuretools.vscode-docker
            vscode.ms-python.python
            vscode.ms-toolsai.jupyter
            vscode.ms-vscode.cmake-tools
            vscode.ms-vscode-remote.remote-ssh
            vscode.myriad-dreamin.tinymist
            vscode.oderwat.indent-rainbow
            vscode.openai.chatgpt
            vscode.pkief.material-icon-theme
            vscode.redhat.vscode-yaml
            vscode.rust-lang.rust-analyzer
            vscode.streetsidesoftware.code-spell-checker
            vscode.tonybaloney.vscode-pets
            vscode.vscodevim.vim
            vscode.wakatime.vscode-wakatime
          ];
        enableExtensionUpdateCheck = false;
        enableUpdateCheck = false;
        userSettings = {
          "vscode-neovim.neovimExecutablePaths.darwin" = "/etc/profiles/per-user/${config.my.name}/bin/nvim";
          # "vscode-neovim.neovimInitPath" = "~/.config/nvim/vscode/init.vim";

          "claudeCode.preferredLocation" = "panel";
          "chat.disableAIFeatures" = false;
          "clangd.path" = "${lib.getExe' pkgs.clang-tools "clangd"}";
          "editor.cursorBlinking" = "solid";
          "editor.cursorSmoothCaretAnimation" = "on";
          "editor.fontFamily" = "Fira Code";
          "editor.fontLigatures" = true;
          "editor.fontSize" = 15;
          "editor.fontWeight" = if pkgs.stdenv.hostPlatform.isDarwin then 400 else 500;
          "editor.inlineSuggest.enabled" = true;
          "editor.smoothScrolling" = true;
          "editor.unicodeHighlight.allowedLocales"."zh-hant" = true;
          "extensions.autoUpdate" = false;
          "github.copilot.editor.enableAutoCompletions" = true;
          "github.copilot.enable" = {
            "*" = true;
            markdown = true;
            plaintext = false;
            scminput = false;
          };
          "git.blame.editorDecoration.enabled" = true;
          "gitlens.launchpad.indicator.enabled" = false;
          "gitlens.plusFeatures.enabled" = false;
          "gitlens.showWelcomeOnInstall" = false;
          "gitlens.showWhatsNewAfterUpgrades" = false;
          "redhat.telemetry.enabled" = false;
          "rust-analyzer.server.path" = "${lib.getExe' pkgs.rust-analyzer "rust-analyzer"}";
          "security.workspace.trust.banner" = "never";
          "security.workspace.trust.startupPrompt" = "never";
          "security.workspace.trust.untrustedFiles" = "newWindow";
          "terminal.integrated.allowChords" = false;
          "terminal.integrated.cursorStyle" = "underline";
          "terminal.integrated.fontFamily" = "Brass Mono Code";
          "terminal.integrated.fontLigatures" = true;
          "terminal.integrated.fontSize" = 15;
          "terminal.integrated.fontWeight" = if pkgs.stdenv.hostPlatform.isDarwin then 400 else 500;
          "terminal.integrated.macOptionIsMeta" = true;
          "terminal.integrated.sendKeybindingsToShell" = true;
          "terminal.integrated.smoothScrolling" = true;
          "update.mode" = "none";
          "vscode-pets.petColor" = "white";
          "vscode-pets.petSize" = "small";
          "vscode-pets.throwBallWithMouse" = true;
          "window.titleBarStyle" = "custom";
          "workbench.colorCustomizations"."git.blame.editorDecorationForeground" = "#686f7d";
          "workbench.colorTheme" = "One Monokai";
          "workbench.iconTheme" = "material-icon-theme";
          "workbench.list.smoothScrolling" = true;
          "workbench.productIconTheme" = "icons-carbon";
        };
      };
    };

    # Remove the generated extension directory before Home Manager links it again.
    home.activation.resetVSCodium = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      $DRY_RUN_CMD rm -rf $VERBOSE_ARG "$HOME/.vscode-oss/extensions"
    '';
  };
}
