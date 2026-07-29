{
  lib,
  config,
  osConfig,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib.generators) toLua;
  inherit (lib.meta) getExe getExe';
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkForce mkIf;
  inherit (lib.dot)
    relativeToConfig
    uwsmApp
    uwsmScript
    withUWSM
    withUWSM'
    ;
  inherit (config.my.gui) desktop;
  cfg = desktop.hyprland;
  dynamicCursors = pkgs.hyprlandPlugins.hypr-dynamic-cursors.overrideAttrs (_: {
    version = "0-unstable-2026-07-21";
    src = pkgs.fetchFromGitHub {
      owner = "VirtCode";
      repo = "hypr-dynamic-cursors";
      rev = "f5ba36c7622098b53bf62ddb8ddf03b914abbdf8";
      hash = "sha256-HKzJtEkafkWjTx35spDp6pm1oClN7vIipJ2wwU4ocNY=";
    };
  });
  terminal = config.my.gui.terminal.exec;
  browser = config.my.gui.browser.exec;
  fileManager = config.my.gui.fileManager.exec;
  key = osConfig.dot.keyboard.keys;
  monitorToLua = monitor: {
    output = monitor.name;
    mode = monitor.resolution;
    inherit (monitor) position;
    inherit (monitor) scale;
  };
  lang = "eng+chi_sim+chi_tra";
  noctaliaEnabled = config.programs.noctalia.enable or false;
  dmsEnabled = config.programs.dank-material-shell.enable or false;
  dmsExe = getExe' inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default "dms";
  shellBackend =
    if desktop.shell.default == "noctalia" && noctaliaEnabled then
      "noctalia"
    else if desktop.shell.default == "dank-material-shell" && dmsEnabled then
      "dank-material-shell"
    else
      "none";
  launcherBackend =
    if desktop.launcher.default == "shell" && shellBackend == "none" then
      "none"
    else
      desktop.launcher.default;
  shotBackend =
    if desktop.shot.default == null then
      "none"
    else if desktop.shot.default == "shell" && shellBackend == "none" then
      "none"
    else
      desktop.shot.default;
  wl-ocr = uwsmScript pkgs "wl-ocr" ''
    ${getExe pkgs.grim} -g "$(${getExe pkgs.slurp})" - | ${getExe pkgs.tesseract} ${lang} - - | ${getExe' pkgs.wl-clipboard "wl-copy"}
  '';
  screenshotRegion = uwsmScript pkgs "wayland-region-shot" ''
    ${getExe pkgs.grim} -g "$(${getExe pkgs.slurp})" - | ${getExe pkgs.satty} --filename -
  '';
  keyboardBacklightToggle = uwsmScript pkgs "keyboard-backlight-toggle" ''
    current=$(${getExe pkgs.brightnessctl} --device="*::kbd_backlight" get)
    if [ "$current" -eq 0 ]; then
      ${getExe pkgs.brightnessctl} --device="*::kbd_backlight" set 100%
    else
      ${getExe pkgs.brightnessctl} --device="*::kbd_backlight" set 0
    fi
  '';
  hasNixpornTheme = osConfig ? nixporn && osConfig.nixporn ? palette;
  theme = lib.optionalAttrs hasNixpornTheme (
    let
      inherit (osConfig.nixporn) palette;
      inherit (palette) ansi;
      colorscheme = osConfig.nixporn.colorschemes.${osConfig.nixporn.colorscheme};
      accentName = colorscheme.accent or "blue";
      accent = if builtins.hasAttr accentName palette then palette.${accentName} else ansi.blue;
      hex = color: lib.removePrefix "#" color;
      rgb = color: "rgb(${hex color})";
      rgba = color: alpha: "rgba(${hex color}${alpha})";
    in
    {
      active_border = rgb accent;
      inactive_border = rgb ansi.bright_black;
      group_active = rgb accent;
      group_inactive = rgb ansi.black;
      group_locked_active = rgb ansi.cyan;
      group_text = rgb ansi.fg;
      background = rgb ansi.bg;
      shadow = rgba ansi.bg "99";
    }
  );
  generated = {
    mod = desktop.modKey;
    workspaces = desktop.workspace.number;
    inherit theme;
    backends = {
      launcher = launcherBackend;
      shell = shellBackend;
      shot = shotBackend;
    };
    keys = {
      inherit (key)
        I
        N
        h
        j
        k
        l
        e
        ;
    };
    commands = {
      inherit terminal;
      inherit browser;
      file_manager = fileManager;
      ocr = wl-ocr;
      screenshot_region = screenshotRegion;
      keyboard_backlight_toggle = keyboardBacklightToggle;
      playerctl = uwsmApp pkgs (getExe pkgs.playerctl) [ ];
      wpctl = uwsmApp pkgs (getExe' pkgs.wireplumber "wpctl") [ ];
      brightnessctl = uwsmApp pkgs (getExe pkgs.brightnessctl) [ ];
      noctalia = uwsmApp pkgs (getExe config.programs.noctalia.package) [ "msg" ];
      dms = uwsmApp pkgs dmsExe [ ];
      dms_ipc = uwsmApp pkgs dmsExe [
        "ipc"
        "call"
      ];
      vicinae = uwsmApp pkgs (getExe config.programs.vicinae.package) [ ];
      hyprshot = uwsmApp pkgs (getExe pkgs.hyprshot) [ ];
      grimblast = uwsmApp pkgs (getExe pkgs.grimblast) [ ];
      satty = uwsmApp pkgs (getExe pkgs.satty) [ ];
    };
    startup = [
      "${withUWSM pkgs "wl-clip-persist"} --clipboard regular"
      "${withUWSM' pkgs pkgs.wl-clipboard "wl-paste"} --type text --watch ${getExe pkgs.cliphist} store"
      "${withUWSM' pkgs pkgs.wl-clipboard "wl-paste"} --type image --watch ${getExe pkgs.cliphist} store"
    ];
    monitors = builtins.map monitorToLua osConfig.dot.device.monitors;
    plugins = {
      dynamic_cursors = "${dynamicCursors}/lib/libhypr-dynamic-cursors.so";
    };
  };
in
{
  options.my.gui.desktop.hyprland = {
    enable = mkEnableOption "Enable Hyprland" // {
      default = osConfig.dot.gui.desktop.wayland.enable && osConfig.dot.gui.desktop.default == "hyprland";
      internal = true;
      readOnly = true;
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.lua5_4 ];

    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      settings = mkForce { };
      xwayland.enable = true;
      systemd = {
        enable = false;
        variables = [ "--all" ];
        extraCommands = [
          "systemctl --user stop graphical-session.target"
          "systemctl --user start hyprland-session.target"
        ];
      };
    };

    xdg.configFile = {
      "hypr/hyprland.lua".source = relativeToConfig "hypr/hyprland.lua";
      "hypr/hypr".source = relativeToConfig "hypr/hypr";
      "hypr/plugins".source = relativeToConfig "hypr/plugins";
      "hypr/generated.lua".text = ''
        -- Generated by Home Manager. Edit config/hypr/hyprland.lua for static config.
        return ${toLua { } generated}
      '';
    };
  };
}
