{
  description = "A batteries-included C++20 project template";

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
          cpp-app = pkgs.callPackage ./nix/package.nix { };
        in
        {
          inherit cpp-app;
          default = cpp-app;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (pkgs) lib;
          cppApp = {
            type = "app";
            program = lib.getExe self.packages.${system}.cpp-app;
            meta.description = "Run the C++ application";
          };
          generateCompileCommands = generateCompileCommandsAppFor pkgs;
        in
        {
          default = cppApp;
          cpp-app = cppApp;
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
          package = self.packages.${system}.cpp-app;

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
          preCommitCheck = self.checks.${system}.pre-commit-check;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.cpp-app ];
            packages =
              preCommitCheck.enabledPackages
              ++ [
                pkgs.clang-tools
                pkgs.cmake-format
                (generateCompileCommandsFor pkgs)
                (runClangTidyFor pkgs)
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.gdb ];

            shellHook = ''
              ${preCommitCheck.shellHook}
              export CMAKE_GENERATOR=Ninja
              echo "C++20 development environment"
              echo "Run 'generate-compile-commands' to configure clangd."
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
        pkgs.writeShellScriptBin "cpp-app-format" ''
          exec ${pkgs.lib.getExe package} run --all-files --config ${configFile}
        ''
      );
    };
}
