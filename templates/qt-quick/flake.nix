{
  description = "A batteries-included C++23 and Qt Quick project template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
      generateCompileCommandsFor =
        pkgs:
        pkgs.writeShellApplication {
          name = "generate-compile-commands";
          runtimeInputs = [
            pkgs.cmake
            pkgs.git
            pkgs.ninja
          ];
          text = builtins.readFile ./scripts/generate-compile-commands;
        };
      generateCompileCommandsAppFor =
        pkgs:
        pkgs.writeShellApplication {
          name = "generate-compile-commands";
          runtimeInputs = [
            pkgs.git
            pkgs.nix
          ];
          text = ''
            project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            cd "$project_root"
            exec nix develop --command generate-compile-commands "$@"
          '';
        };
      runClangTidyFor =
        pkgs:
        pkgs.writeShellApplication {
          name = "run-clang-tidy";
          runtimeInputs = [
            pkgs.clang-tools
            pkgs.cmake
            pkgs.findutils
            pkgs.git
            pkgs.ninja
          ];
          text = builtins.readFile ./scripts/run-clang-tidy;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          qt-quick-app = pkgs.callPackage ./nix/package.nix { };
        in
        {
          inherit qt-quick-app;
          default = qt-quick-app;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (pkgs) lib;
          qtQuickApp = {
            type = "app";
            program = lib.getExe self.packages.${system}.qt-quick-app;
            meta.description = "Run the Qt Quick application";
          };
          generateCompileCommands = generateCompileCommandsAppFor pkgs;
        in
        {
          default = qtQuickApp;
          qt-quick-app = qtQuickApp;
          generate-compile-commands = {
            type = "app";
            program = lib.getExe generateCompileCommands;
            meta.description = "Generate compile_commands.json for clangd and IDEs";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (pkgs) lib;
          clangTidy = runClangTidyFor pkgs;
        in
        {
          package = self.packages.${system}.qt-quick-app;

          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              check-added-large-files.enable = true;
              check-case-conflicts.enable = true;
              check-merge-conflicts.enable = true;
              clang-format = {
                enable = true;
                types_or = lib.mkForce [
                  "c"
                  "c++"
                ];
              };
              clang-tidy = {
                enable = true;
                name = "clang-tidy";
                entry = lib.getExe clangTidy;
                files = "\\.(cc|cpp|cxx)$";
                pass_filenames = true;
                require_serial = true;
                stages = [ "pre-push" ];
              };
              cmake-format.enable = true;
              deadnix.enable = true;
              end-of-file-fixer.enable = true;
              mixed-line-endings.enable = true;
              nixfmt.enable = true;
              statix.enable = true;
              trim-trailing-whitespace.enable = true;
              typos.enable = true;
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (pkgs) lib;
          preCommitCheck = self.checks.${system}.pre-commit-check;
          qtRuntimePackages = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtdeclarative
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.qt6.qtwayland ];
          qtPluginPath = lib.makeSearchPath pkgs.qt6.qtbase.qtPluginPrefix qtRuntimePackages;
          qmlImportPath = lib.makeSearchPath pkgs.qt6.qtbase.qtQmlPrefix qtRuntimePackages;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.qt-quick-app ];
            packages =
              preCommitCheck.enabledPackages
              ++ [
                pkgs.clang-tools
                pkgs.cmake-format
                pkgs.just
                pkgs.qt6.qttools
                (generateCompileCommandsFor pkgs)
                (runClangTidyFor pkgs)
              ]
              ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.gdb ];

            shellHook = ''
              ${preCommitCheck.shellHook}
              export CMAKE_GENERATOR=Ninja
              export QT_PLUGIN_PATH="${qtPluginPath}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
              export QML_IMPORT_PATH="${qmlImportPath}''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
              export NIXPKGS_QT6_QML_IMPORT_PATH="${qmlImportPath}''${NIXPKGS_QT6_QML_IMPORT_PATH:+:$NIXPKGS_QT6_QML_IMPORT_PATH}"
              echo "Qt ${pkgs.qt6.qtbase.version} Quick development environment"
              echo "Run 'just check' to configure, build, and test the project."
            '';
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (self.checks.${system}.pre-commit-check.config) package configFile;
        in
        pkgs.writeShellScriptBin "qt-quick-app-format" ''
          exec ${pkgs.lib.getExe package} run --all-files --config ${configFile}
        ''
      );
    };
}
