{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.modules) mkIf;

  steamLibrary = "$HOME/.local/share/Steam/steamapps/common";
  systemdSteamLibrary = "%h/.local/share/Steam/steamapps/common";

  nativeGameFixes = {
    tomb-raider = {
      installDirectory = "Tomb Raider";
      executable = "bin/TombRaider";
      launcher = "TombRaider.sh";
      environment.SDL_VIDEODRIVER = "x11";
      requiredPaths = [ "lib/i686/libicui18n.so.51" ];
      rpath = [
        "$ORIGIN/../lib/i686"
        "$ORIGIN/../lib"
      ];
    };
  };

  makeFixer =
    name: fix:
    let
      desiredRpath = lib.concatStringsSep ":" fix.rpath;
      environmentBlock = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (variable: value: "export ${variable}=${lib.escapeShellArg value}") (
          fix.environment or { }
        )
      );
    in
    pkgs.writeShellApplication {
      name = "fix-native-game-${name}";
      runtimeInputs = [
        pkgs.diffutils
        pkgs.gnugrep
        pkgs.patchelf
      ];
      text = ''
        game_root="${steamLibrary}/${fix.installDirectory}"
        executable="$game_root/${fix.executable}"
        # patchelf must receive the literal $ORIGIN token.
        # shellcheck disable=SC2016
        desired_rpath=${lib.escapeShellArg desiredRpath}
        changed=0

        if [[ ! -x "$executable" ]]; then
          exit 0
        fi

        ${lib.concatMapStringsSep "\n" (path: ''
          required_path="$game_root/"${lib.escapeShellArg path}
          if [[ ! -e "$required_path" ]]; then
            printf 'native game fix %s: required path is missing: %s\n' \
              ${lib.escapeShellArg name} "$required_path" >&2
            exit 1
          fi
        '') fix.requiredPaths}

        if ! current_rpath="$(patchelf --print-rpath "$executable")"; then
          printf 'native game fix %s: failed to read RPATH: %s\n' \
            ${lib.escapeShellArg name} "$executable" >&2
          exit 1
        fi

        if [[ "$current_rpath" != "$desired_rpath" ]]; then
          patchelf --force-rpath --set-rpath "$desired_rpath" "$executable"

          if [[ "$(patchelf --print-rpath "$executable")" != "$desired_rpath" ]]; then
            printf 'native game fix %s: failed to verify RPATH: %s\n' \
              ${lib.escapeShellArg name} "$executable" >&2
            exit 1
          fi

          changed=1
        fi

        ${lib.optionalString (fix ? launcher && environmentBlock != "") ''
          launcher="$game_root/${fix.launcher}"
          begin_marker=${lib.escapeShellArg "# BEGIN native-game-fix:${name}"}
          end_marker=${lib.escapeShellArg "# END native-game-fix:${name}"}
          environment_block=${lib.escapeShellArg environmentBlock}

          if [[ ! -x "$launcher" ]]; then
            printf 'native game fix %s: launcher is missing or not executable: %s\n' \
              ${lib.escapeShellArg name} "$launcher" >&2
            exit 1
          fi

          begin_count="$(grep -Fxc -- "$begin_marker" "$launcher" || true)"
          end_count="$(grep -Fxc -- "$end_marker" "$launcher" || true)"
          if (( begin_count > 1 || begin_count != end_count )); then
            printf 'native game fix %s: invalid managed block in launcher: %s\n' \
              ${lib.escapeShellArg name} "$launcher" >&2
            exit 1
          fi

          temp_launcher="$(mktemp --tmpdir="$game_root" ".native-game-fix-${name}.XXXXXX")"
          cleanup() {
            rm -f -- "$temp_launcher"
          }
          trap cleanup EXIT

          {
            if ! IFS= read -r first_line; then
              printf 'native game fix %s: launcher is empty: %s\n' \
                ${lib.escapeShellArg name} "$launcher" >&2
              exit 1
            fi

            if [[ "$first_line" != '#!'* ]]; then
              printf 'native game fix %s: launcher has no shebang: %s\n' \
                ${lib.escapeShellArg name} "$launcher" >&2
              exit 1
            fi

            printf '%s\n%s\n%s\n%s\n' \
              "$first_line" "$begin_marker" "$environment_block" "$end_marker"

            skipping_managed_block=0
            while IFS= read -r line || [[ -n "$line" ]]; do
              if [[ "$line" == "$begin_marker" ]]; then
                skipping_managed_block=1
                continue
              fi

              if (( skipping_managed_block )); then
                if [[ "$line" == "$end_marker" ]]; then
                  skipping_managed_block=0
                fi
                continue
              fi

              printf '%s\n' "$line"
            done
          } < "$launcher" > "$temp_launcher"

          if ! cmp -s -- "$launcher" "$temp_launcher"; then
            chmod --reference="$launcher" "$temp_launcher"
            mv -- "$temp_launcher" "$launcher"
            changed=1
          fi
        ''}

        if (( changed )); then
          printf 'native game fix %s: updated %s\n' \
            ${lib.escapeShellArg name} "$game_root"
        fi
      '';
    };

  fixers = lib.mapAttrs makeFixer nativeGameFixes;
in
{
  config =
    mkIf (config.dot.gui.enable && config.dot.gui.game.enable && pkgs.stdenv.hostPlatform.isLinux)
      {
        systemd.user = {
          services = lib.mapAttrs' (
            name: _fix:
            lib.nameValuePair "native-game-fix-${name}" {
              description = "Apply native game compatibility fix for ${name}";
              wantedBy = [ "default.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe fixers.${name};
              };
            }
          ) nativeGameFixes;

          paths = lib.mapAttrs' (
            name: fix:
            let
              executable = "${systemdSteamLibrary}/${fix.installDirectory}/${fix.executable}";
              watchedPaths = [
                executable
              ]
              ++ lib.optional (fix ? launcher) "${systemdSteamLibrary}/${fix.installDirectory}/${fix.launcher}";
              unitName = "native-game-fix-${name}";
            in
            lib.nameValuePair unitName {
              description = "Watch the native game executable for ${name}";
              wantedBy = [ "default.target" ];
              pathConfig = {
                PathChanged = watchedPaths;
                Unit = "${unitName}.service";
              };
            }
          ) nativeGameFixes;
        };
      };
}
