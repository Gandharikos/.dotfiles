{
  pkgs,
  config,
  lib,
  osConfig,
  ...
}:
let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib.lists) concatLists head;
  inherit (lib.meta) getExe';
  inherit (lib.strings) concatMapStrings enableFeature getVersion;
  inherit (lib.types) nullOr str;
  inherit (lib.versions) splitVersion;
  inherit (lib.dot) uwsmAppArgs;
  cfg = config.my.gui.apps.chromium;
  enable = osConfig.dot.gui.enable && cfg.enable;

  features = en: features: "--${en}-features=" + (concatMapStrings (x: x + ",") features);

  withVaapiDriver =
    driver: override: args:
    let
      package = override args;
    in
    if driver == null then
      package
    else
      pkgs.symlinkJoin {
        name = "${package.name}-${driver}";
        inherit (package) meta version;
        paths = [ package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/chromium" \
            --set LIBVA_DRIVER_NAME ${lib.escapeShellArg driver}
          ln -sf chromium "$out/bin/chromium-browser"
        '';
      };

  extension =
    {
      id,
      version,
      hash,
    }:
    {
      inherit id version;
      crxPath = pkgs.fetchurl {
        name = "${id}.crx";
        url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=${head (splitVersion (getVersion config.programs.chromium.package))}&x=id%3D${id}%26installsource%3Dondemand%26uc";
        inherit hash;
      };
    };
in
{
  options.my.gui.apps.chromium = {
    enable = mkEnableOption "Chromium" // {
      default = config.my.gui.browser.default == "chromium";
    };

    vaapiDriver = mkOption {
      type = nullOr str;
      default = null;
      description = "VA-API driver to use for Chromium video decoding.";
    };
  };

  config = mkIf enable {
    programs.chromium = {
      enable = true;

      extensions = map extension [
        # OneTab
        {
          id = "chphlpgkkbolifaimnlloiipkdnihall";
          version = "2.18";
          hash = "sha256-BWg/RRnN6/lVmf1Pc07vzA3noGaNX3J64IrCKuAV5Qk=";
        }

        # Obsidian Web Clipper
        {
          id = "cnjifjpddelmedmihgijeibhnjfabmlf";
          version = "1.7.1";
          hash = "sha256-H32I06Rx3LArg1/ysJfcsapIpwWlUufkwu9Xamx1NGc=";
        }

        # Dark Reader
        {
          id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
          version = "4.9.129";
          hash = "sha256-ncsb1tytQ4kt3AKP9l+YLfPtuhNammRF5PpxZx43qhM=";
        }

        # Vimium C
        {
          id = "hfjbmagddngcpeloejdejnfgbamkjaeg";
          version = "2.12.2";
          hash = "sha256-1kiLH+QIjOIheJXFNE/BKJ7tWZLvwHpr6ec1cLIlBCM=";
        }

        # Undo Closed Tabs Button
        {
          id = "ieehkmoiljghfkejgahoheemdjpdinml";
          version = "0.2.4";
          hash = "sha256-AEdtNiDLyhjTC0sFptdwFpiVRD4K03/cf4atcD0BPes=";
        }

        # Vicinae Integration
        {
          id = "kcmipingpfbohfjckomimmahknoddnke";
          version = "1.0.0";
          hash = "sha256-P9ZWnHGwYhdOMEU0onWb8nAPfczi//HpgQ4H/yLdPx0=";
        }

        # Unhook
        {
          id = "khncfooichmfjbepaaaebmommgaepoid";
          version = "1.6.9";
          hash = "sha256-hiKyaY3/CLquJqjDY49STmbfwSVi5yhpSBn6HvLigCM=";
        }

        # BroTab
        {
          id = "mhpeahbikehnfkfnmopaigggliclhmnc";
          version = "1.4.0";
          hash = "sha256-rgoYW39JbAyER/ilFB2f1ellMTLeS5wVGs4fDv2ccrU=";
        }

        # Video Speed Controller
        {
          id = "nffaoalbilbmmfgbnbgppjihopabppdk";
          version = "0.10.2";
          hash = "sha256-bJUxLYTCx+UCbpxZW0+By4NfK2oiYxWbhy+766a0dUY=";
        }

        # ChatGPT Equation Renderer
        {
          id = "nkkkaendbndanjjndfpebmekhgdjlhkh";
          version = "1.1.2";
          hash = "sha256-kVxQHBr0LQhdk2yPS/+ue2BrHQrxNPTqShL8xSuLjDM=";
        }

        # Linkwarden
        {
          id = "pnidmkljnhbjfffciajlcpeldoljnidn";
          version = "1.5.4";
          hash = "sha256-EMi7YP40UNYQ1qZ5Rf1eRWvfaIJIGqma0PepcyIyl4k=";
        }

        # uBlock Origin
        {
          id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
          version = "1.72.2";
          hash = "sha256-bgLY5tzlae7HIbUx+cfShAPlQmRCQX1ahVoX3SiLVvg=";
        }

        # stylus
        {
          id = "clngdbkpkpeebahjckkjfobafhncgmne";
          version = "2.4.5";
          hash = "sha256-mST2glhYqJuYce1SDxnqHdSIaVsGJ/m5CTcE8Tlib2E=";
        }

        # Bitwarden
        {
          id = "nngceckbapebfimnlniiiahkandclblb";
          version = "2026.7.0";
          hash = "sha256-PwXLkgGS9YjvBRUHgwiEtqiXkXmWngv3xA4Boqj9f74=";
        }

        # at://wormhole
        {
          id = "aihndpeeoneojofmliffjknbegmipbim";
          version = "1.1.0";
          hash = "sha256-oR4q4U1R5GDjCkwwjZSMU0amR91+T1h76cpsjOxnGiM=";
        }

        # SponsorBlock
        {
          id = "mnjggcdmjocbbbhaepdhchncahnbgone";
          version = "6.1.6";
          hash = "sha256-VYf+K2qZRhAcoN3nxu/nanVcXuW21uY9/EjH9zbNtP8=";
        }

        # Volume Master
        {
          id = "jghecgabfgfdldnmbfkhmffcabddioke";
          version = "2.4.0";
          hash = "sha256-dSLS7Km/5gbb07xEYACAOs9EBfvbJGlqx4qwFkKV95U=";
        }

        # scriptcat
        {
          id = "ndcooeababalnlpkfedmmbbbgkljhpjf";
          version = "1.4.0";
          hash = "sha256-8YLHEQogwSB+EDKIFqJycj5JcGHhRZxLwxYMS22ZRZ0=";
        }

        # ff2mpv
        {
          id = "ephjcajbkgplkjmelpglennepbpmdpjg";
          version = "6.0.0";
          hash = "sha256-4VEwf3rqtobbOElIsYi1mIcIvFS3KXlpHYfs3d+AzGg=";
        }

        # Control Panel for Twitter
        {
          id = "kpmjjdhbcfebfjgdnpjagcndoelnidfj";
          version = "4.23.0";
          hash = "sha256-6H757aZJv1ArCN2qVMkn4WX9CFtE6CWfOzGggp1X1Cc=";
        }

        # refined github
        {
          id = "hlepfoohegkhhmjieoechaddaejaokhf";
          version = "26.7.26";
          hash = "sha256-G0ht0WUH+I5e7UJHbw9NvTKvV77rNjP8ox9PKbvJMYI=";
        }
      ];

      nativeMessagingHosts = [ pkgs.ff2mpv-rust ];

      package = withVaapiDriver cfg.vaapiDriver pkgs.ungoogled-chromium.override {
        enableWideVine = true;

        # https://github.com/secureblue/hardened-chromium
        # https://github.com/secureblue/secureblue/blob/e500f078efc5748d5033a881bbbcdcd2de95a813/files/system/usr/etc/chromium/chromium.conf.md
        commandLineArgs = concatLists [
          # Aesthetics
          [
            "--gtk-version=4"
            "--vertical-tabs"
          ]

          # Performance
          [
            (enableFeature true "gpu-rasterization")
            (enableFeature true "oop-rasterization")
            (enableFeature true "zero-copy")

            # share a process per site
            "--process-per-site"

            # allow parallel downloads
            (enableFeature true "parallel-downloading")

            # vaapi info: https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/gpu/vaapi.md
            "--ignore-gpu-blocklist"
            "--disable-gpu-driver-bug-workaround"
          ]

          # Wayland
          [ "--ozone-platform=wayland" ]

          # Etc
          [
            "--disk-cache=$XDG_RUNTIME_DIR/chromium-cache"

            "--no-first-run"
            "--disable-wake-on-wifi"
            "--disable-breakpad"

            # please stop asking me to be the default browser
            "--no-default-browser-check"

            # hdr some others too
            (enableFeature true "experimental-web-platform-features")

            # I don't need these, thus I disable them
            (enableFeature false "speech-api")
            (enableFeature false "speech-synthesis-api")
          ]

          # Security
          [
            # Disable pings
            "--no-pings"

            # Require HTTPS for component updater
            "--component-updater=require_encryption"

            # Disable crash upload
            "--no-crash-upload"

            # don't run things without asking
            "--no-service-autorun"

            # Disable sync
            "--disable-sync"

            # disable canvas reading for privacy
            # (enableFeature false "reading-from-canvas")

            "--password-store=gnome-libsecret"
          ]

          [
            (features "enable" [
              # needed for wayland
              "UseOzonePlatform"

              "MiddleClickAutoscroll"

              # allow manifest v2
              "AllowLegacyMV2Extensions"

              # see the performance section as to why these are added
              "AcceleratedVideoEncoder"
              "AcceleratedVideoDecodeLinuxGL"
              "WaylandLinuxDrmSyncobj"

              # Enable visited link database partitioning
              "PartitionVisitedLinkDatabase"

              # Enable prefetch privacy changes
              "PrefetchPrivacyChanges"

              # Enable split cache
              "SplitCacheByNetworkIsolationKey"
              "SplitCodeCacheByNetworkIsolationKey"

              # Enable partitioning connections
              "EnableCrossSiteFlagNetworkIsolationKey"
              "HttpCacheKeyingExperimentControlGroup"
              "PartitionConnectionsByNetworkIsolationKey"

              # Enable strict origin isolation
              "StrictOriginIsolation"

              # Enable reduce accept language header
              "ReduceAcceptLanguage"

              # Enable content settings partitioning
              "ContentSettingsPartitioning"
            ])

            (features "disable" [
              # Disable autofill
              "AutofillPaymentCardBenefits"
              "AutofillPaymentCvcStorage"
              "AutofillPaymentCardBenefits"

              # Disable third-party cookie deprecation bypasses
              "TpcdHeuristicsGrants"
              "TpcdMetadataGrants"

              # Disable hyperlink auditing
              "EnableHyperlinkAuditing"

              # Disable showing popular sites
              "NTPPopularSitesBakedInContent"
              "UsePopularSitesSuggestions"

              # Disable article suggestions
              "EnableSnippets"
              "ArticlesListVisible"
              "EnableSnippetsByDse"

              # Disable content feed suggestions
              "InterestFeedV2"

              # Disable media DRM preprovisioning
              "MediaDrmPreprovisioning"

              # Disable autofill server communication
              "AutofillServerCommunication"

              # Disable new privacy sandbox features
              "PrivacySandboxSettings4"
              "BrowsingTopics"
              "BrowsingTopicsDocumentAPI"
              "BrowsingTopicsParameters"

              # Disable translate button
              "AdaptiveButtonInTopToolbarTranslate"

              # Disable detailed language settings
              "DetailedLanguageSettings"

              # Disable fetching optimization guides
              "OptimizationHintsFetching"

              # Partition third-party storage
              "DisableThirdPartyStoragePartitioningDeprecationTrial2"

              # Disable media engagement
              "PreloadMediaEngagementData"
              "MediaEngagementBypassAutoplayPolicies"

              # allow manifest v2
              "ExtensionsManifestV3Only"
              "ExtensionManifestV2Unsupported"
              "ExtensionManifestV2Disabled"
            ])
          ]
        ];
      };
    };

    my.gui.browser = mkIf (config.my.gui.browser.default == "chromium") {
      desktopId = "chromium-browser.desktop";
      command =
        if osConfig.dot.gui.desktop.uwsm.enable then
          uwsmAppArgs pkgs (getExe' config.programs.chromium.package "chromium") [ ]
        else
          [ (getExe' config.programs.chromium.package "chromium") ];
    };
  };
}
