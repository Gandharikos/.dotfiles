{
  config,
  lib,
  pkgs,
  aiCommon,
  ...
}:
let
  cfg = config.my.codex;
  inherit (lib)
    getExe
    getExe'
    mkEnableOption
    mkOption
    mkIf
    optionalString
    optionals
    ;
  headroomEnabled = cfg.useHeadroom;
  mcpModuleEnabled = config.my.mcp.enable or false;
  devRoot = "${config.home.homeDirectory}/Dev";
  projectRootMarkers = [
    ".git"
    ".jj"
    ".hg"
    ".sl"
  ];
  codexWithTrustedDevProjects = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = [ pkgs.coreutils ];
    meta = pkgs.codex.meta;
    text = ''
      launchDirectory="$PWD"
      expectsDirectory=false

      for argument in "$@"; do
        if [[ "$expectsDirectory" == true ]]; then
          launchDirectory="$argument"
          expectsDirectory=false
          continue
        fi

        case "$argument" in
          -C | --cd)
            expectsDirectory=true
            ;;
          -C?*)
            launchDirectory="''${argument#-C}"
            ;;
          --cd=*)
            launchDirectory="''${argument#--cd=}"
            ;;
        esac
      done

      launchDirectory="$(realpath -m -- "$launchDirectory")"
      codexArguments=(--dangerously-bypass-hook-trust)

      case "$launchDirectory" in
        ${devRoot} | ${devRoot}/*)
          projectRoot="$launchDirectory"
          candidate="$launchDirectory"

          while [[ "$candidate" == ${devRoot} || "$candidate" == ${devRoot}/* ]]; do
            foundMarker=false
            for marker in ${lib.escapeShellArgs projectRootMarkers}; do
              if [[ -e "$candidate/$marker" ]]; then
                projectRoot="$candidate"
                foundMarker=true
                break
              fi
            done

            if [[ "$foundMarker" == true || "$candidate" == ${devRoot} ]]; then
              break
            fi
            candidate="$(dirname -- "$candidate")"
          done

          escapedProjectRoot="''${projectRoot//\\/\\\\}"
          escapedProjectRoot="''${escapedProjectRoot//\"/\\\"}"
          trustOverride='projects={"'
          trustOverride+="$escapedProjectRoot"
          trustOverride+='"={trust_level="trusted"}}'
          codexArguments+=(
            -c
            "$trustOverride"
          )
          ;;
      esac

      exec ${getExe pkgs.codex} "''${codexArguments[@]}" "$@"
    '';
  };
in
{
  options.my.codex = {
    enable = mkEnableOption "codex";
    useHeadroom = mkOption {
      type = lib.types.bool;
      default = config.my.headroom.enable or false;
      description = "Whether to use headroom token-compression proxy for Codex.";
    };
  };

  config = mkIf cfg.enable {
    programs.codex = {
      enable = true;
      enableMcpIntegration = mcpModuleEnabled;
      package = codexWithTrustedDevProjects;

      settings = {
        features = {
          apps = true;
          browsesr_use = true;
          browser_user_external = true;
          code_mode_host = true;
          computer_use = true;
          enable_request_compression = true;
          fast_mode = true;
          goals = true;
          guardian_approval = true;
          hooks = true;
          image_generation = true;
          in_app_browser = true;
          memories = true;
          multi_agent = true;
          personality = true;
          plugin_sharing = true;
          plugins = true;
          prevent_idle_sleep = true;
          shell_snapshot = true;
          shell_tool = true;
          skill_mcp_dependency_install = true;
          terminal_resize_reflow = true;
          tool_call_mcp_elicitaition = true;
          tool_suggestions = true;
          unified_exec = true;
          workspace_dependencies = true;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # Required by codex-browser-use-linux-chromium (codex >= 0.133) so
          # plugin MCP servers are discovered instead of deferred.
          tool_search_always_defer_mcp_tools = false;
        };

        agents = {
          job_max_runtime_seconds = 3600;
          max_depth = 1;
          max_threads = 12;
        };

        history = {
          max_bytes = 104857600;
          persistence = "save-all";
        };

        notice.hide_rate_limit_model_nudge = true;

        model = "gpt-5.6-sol";
        model_provider = mkIf headroomEnabled "headroom";
        model_providers = mkIf headroomEnabled {
          headroom = {
            name = "Headroom";
            base_url = config.my.headroom.openaiBaseUrl;
            env_key = "OPENAI_API_KEY";
            wire_api = "responses";
          };
        };
        model_reasoning_effort = "high";
        plan_mode_reasoning_effort = "high";
        # service_tier = "fast";

        notify =
          let
            codexNotify = pkgs.writeShellApplication {
              name = "codex-notify";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.jq
              ]
              ++ optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.libnotify ]
              ++ optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.terminal-notifier ];
              text = ''
                payload="$1"
                eventType="$(printf '%s' "$payload" | jq -r '.type // ""')"
                [ "$eventType" = "agent-turn-complete" ] || exit 0

                message="$(printf '%s' "$payload" | jq -r '.["last-assistant-message"] // "Turn complete"')"
                summary="$(printf '%s' "$message" | cut -c1-180)"

                ${optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                  ${getExe pkgs.terminal-notifier} -title "Codex" -message "$summary" -group "codex-turn" >/dev/null 2>&1
                ''}
                ${optionalString pkgs.stdenv.hostPlatform.isLinux ''
                  ${getExe' pkgs.libnotify "notify-send"} "Codex" "$summary" >/dev/null 2>&1
                ''}
              '';
            };
          in
          [ (getExe codexNotify) ];

        personality = "pragmatic";

        project_root_markers = projectRootMarkers;

        approval_policy = "on-request";
        sandbox_mode = "danger-full-access";

        tui.keymap.global.clear_terminal = "ctrl-x";

        tui.status_line = [
          "model-with-reasoning"
          "current-dir"
          "context-remaining"
          "context-used"
          "five-hour-limit"
        ];

        projects =
          let
            home = config.home.homeDirectory;
            documentsPath =
              if config.xdg.userDirs.enable then
                config.xdg.userDirs.documents
              else
                home + optionalString pkgs.stdenv.hostPlatform.isLinux "/Documents";
            githubRoot =
              if pkgs.stdenv.hostPlatform.isLinux then "${documentsPath}/github" else "${home}/github";
            devRoot = "${home}/Dev";

            trustedGithubProjects = [
              "home-manager"
              "khanelivim"
              "nixpkgs"
              "nixvim"
              "Austin-Horstman"
              "neotest-nix"
              "waybar"
            ];

            trustedProjects =
              root: projects:
              builtins.listToAttrs (
                map (project: {
                  name = "${root}/${project}";
                  value = {
                    trust_level = "trusted";
                  };
                }) projects
              );
          in
          {
            "${home}/.dotfiles" = {
              trust_level = "trusted";
            };
            "${devRoot}" = {
              trust_level = "trusted";
            };
          }
          // trustedProjects githubRoot trustedGithubProjects;
      };

      profiles = {
        # Deep analysis and live-research mode. Intentionally expensive.
        deep = {
          model = "gpt-5.6-sol";
          model_reasoning_effort = "xhigh";
          model_verbosity = "high";
          plan_mode_reasoning_effort = "xhigh";
          web_search = "live";
        };

        # Large-context escape hatch. The alias passes context overrides directly
        # via CLI -c because those fields are top-level settings in the published
        # schema.
        long = {
          model = "gpt-5.4";
          model_reasoning_effort = "xhigh";
          model_verbosity = "high";
          plan_mode_reasoning_effort = "xhigh";
          web_search = "live";
        };

        # Cheapest local utility profile for triage and simple transforms.
        nano = {
          model = "gpt-5.4-mini";
          model_reasoning_effort = "none";
          model_verbosity = "low";
          plan_mode_reasoning_effort = "low";
          service_tier = "flex";
          web_search = "disabled";
        };

        # Faster implementation loop for routine coding tasks.
        quick = {
          model_reasoning_effort = "medium";
          model = "gpt-5.6-luna";
          model_reasoning_summary = "none";
          model_verbosity = "low";
          plan_mode_reasoning_effort = "medium";
          service_tier = "fast";
          web_search = "disabled";
        };

        # Trivial latency-first profile for obvious, low-risk work.
        spark = {
          model = "gpt-5.3-codex-spark";
          model_reasoning_effort = "medium";
          model_verbosity = "medium";
          plan_mode_reasoning_effort = "high";
          service_tier = "fast";
          web_search = "disabled";
        };

        # Force local-only behavior when you do not want network access.
        offline = {
          sandbox_workspace_write.network_access = false;
          web_search = "disabled";
        };

        # Token-enabled profile for package updates and other API-heavy workflows.
        unsafe = {
          approval_policy = "on-request";
          sandbox_mode = "danger-full-access";
          shell_environment_policy.ignore_default_excludes = true;
        };
      };

      inherit (aiCommon.codex) context;
      rules = import ./rules.nix;
    };
  };
}
