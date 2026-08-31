{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.my.langs.cc;
  enable = config.my.langs.enable && cfg.enable;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  inherit (builtins) isList elemAt;

  cpp17 = pkgs.writeShellApplication {
    name = "cpp17";
    runtimeInputs = [ pkgs.gcc ];
    text = ''
      exec c++ -std=c++17 -Wall -Wextra -O2 "$@"
    '';
  };

  cpp20 = pkgs.writeShellApplication {
    name = "cpp20";
    runtimeInputs = [ pkgs.gcc ];
    text = ''
      exec c++ -std=c++20 -Wall -Wextra -O2 "$@"
    '';
  };

  cpp23 = pkgs.writeShellApplication {
    name = "cpp23";
    runtimeInputs = [ pkgs.gcc ];
    text = ''
      exec c++ -std=c++23 -Wall -Wextra -O2 "$@"
    '';
  };

  cppdbg = pkgs.writeShellApplication {
    name = "cppdbg";
    runtimeInputs = [ pkgs.gcc ];
    text = ''
      exec c++ -std=c++23 -Wall -Wextra -Wshadow -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer "$@"
    '';
  };

  cpprun = pkgs.writeShellApplication {
    name = "cpprun";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gcc
    ];
    text = ''
      if [ "$#" -lt 1 ]; then
        echo "usage: cpprun <source.cc> [args...]" >&2
        exit 2
      fi

      source_file="$1"
      shift
      output_file="''${TMPDIR:-/tmp}/$(basename "''${source_file%.*}")"

      c++ -std=c++23 -Wall -Wextra -O2 "$source_file" -o "$output_file"
      exec "$output_file" "$@"
    '';
  };

  clangNoCpp = pkgs.runCommand "clang-no-cpp" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe pkgs.llvmPackages.clang} "$out/bin/clang"
    makeWrapper ${pkgs.llvmPackages.clang}/bin/clang++ "$out/bin/clang++"
  '';

  mkWrapper =
    package: postBuild:
    let
      name = if isList package then elemAt package 0 else package;
      paths = if isList package then package else [ package ];
    in
    pkgs.symlinkJoin {
      inherit paths postBuild;
      name = "${name}-wrapped";
      buildInputs = [ pkgs.makeWrapper ];
    };
in
{
  options.my.langs.cc = {
    enable = mkEnableOption "C/C++ development environment";
  };

  config = mkIf enable {
    home.packages =
      with pkgs;
      [
        gcc
        clangNoCpp
        llvmPackages.clang-tools
        bear
        cmake
        llvmPackages.libcxx

        # Respect XDG, damn it!
        (mkWrapper gdb ''
          wrapProgram "$out/bin/gdb" --add-flags '-q -x "$XDG_CONFIG_HOME/gdb/init"'
        '')
      ]
      ++ [
        cpp17
        cpp20
        cpp23
        cppdbg
        cpprun
      ];

    programs.fish.shellAbbrs = {
      cc = "cpp23";
      cxx = "cpp23";
      cxx17 = "cpp17";
      cxx20 = "cpp20";
      cxx23 = "cpp23";
      cxxdbg = "cppdbg";
      cpr = "cpprun";
    };

    programs.zsh.zsh-abbr.abbreviations = {
      cc = "cpp23";
      cxx = "cpp23";
      cxx17 = "cpp17";
      cxx20 = "cpp20";
      cxx23 = "cpp23";
      cxxdbg = "cppdbg";
      cpr = "cpprun";
    };

    programs.nushell.shellAliases = {
      cc = "cpp23";
      cxx = "cpp23";
      cxx17 = "cpp17";
      cxx20 = "cpp20";
      cxx23 = "cpp23";
      cxxdbg = "cppdbg";
      cpr = "cpprun";
    };

    xdg.configFile."clangd/config.yaml".text = ''
      If:
        PathMatch: '.*\.(cc|cpp|cxx|c\+\+|hpp|hh|hxx|h\+\+)$'
      CompileFlags:
        Add: [-std=c++23, -Wall, -Wextra]
      Diagnostics:
        ClangTidy:
          Add: [clang-analyzer-*, bugprone-*, performance-*, portability-*, modernize-*]
          Remove: [modernize-use-trailing-return-type]
    '';

    home.file.".clang-format".text = ''
      BasedOnStyle: LLVM
      Standard: Latest
      IndentWidth: 2
      ColumnLimit: 100
      AllowShortFunctionsOnASingleLine: Empty
      DerivePointerAlignment: false
      PointerAlignment: Left
      SortIncludes: CaseSensitive
    '';

    home.file.".clang-tidy".text = ''
      Checks: >
        clang-diagnostic-*,
        clang-analyzer-*,
        bugprone-*,
        performance-*,
        portability-*,
        modernize-*,
        -modernize-use-trailing-return-type,
        -readability-identifier-length,
        -readability-magic-numbers
      WarningsAsErrors: ""
      HeaderFilterRegex: ""
      FormatStyle: file
    '';
  };
}
