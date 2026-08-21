{
  lib,
  config,
  osConfig,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types)
    enum
    int
    str
    nullOr
    package
    ;
  inherit (lib.meta) getExe getExe';
  inherit (lib.strings) escapeShellArgs;
  inherit (config.my.gui) desktop;
  cfg = config.my.gui.desktop.idle;

  # Command executables
  loginctl' = getExe' pkgs.systemd "loginctl";
  brightnessctl' = getExe pkgs.brightnessctl;
  hyprctl' = getExe' pkgs.hyprland "hyprctl";
  niri' = getExe' pkgs.niri "niri";
  brillo' = getExe pkgs.brillo;

  # Shell-specific lock commands
  dmsPkg = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
  dms = getExe' dmsPkg "dms";
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  noctalia = getExe noctaliaPkg;

  shellLock =
    if desktop.shell.default == "noctalia" then
      escapeShellArgs [
        noctalia
        "msg"
        "session"
        "lock"
      ]
    else if desktop.shell.default == "dank-material-shell" then
      escapeShellArgs [
        dms
        "ipc"
        "call"
        "lock"
        "lock"
      ]
    else
      escapeShellArgs [
        loginctl'
        "lock-session"
      ];

  # Screen control commands
  screenOnCmd =
    if osConfig.dot.gui.desktop.default == "hyprland" then
      escapeShellArgs [
        hyprctl'
        "dispatch"
        ''hl.dsp.dpms({ action = "enable" })''
      ]
    else if osConfig.dot.gui.desktop.default == "niri" then
      escapeShellArgs [
        niri'
        "msg"
        "action"
        "power-on-monitors"
      ]
    else
      null;

  screenOffCmd =
    if osConfig.dot.gui.desktop.default == "hyprland" then
      escapeShellArgs [
        hyprctl'
        "dispatch"
        ''hl.dsp.dpms({ action = "disable" })''
      ]
    else if osConfig.dot.gui.desktop.default == "niri" then
      escapeShellArgs [
        niri'
        "msg"
        "action"
        "power-off-monitors"
      ]
    else
      null;

  # Brightness control
  dimScreen = pkgs.writeShellScript "idle-dim-screen" ''
    ${brillo'} -O
    ${brillo'} -u 1000000 -S 10
  '';

  restoreScreen = escapeShellArgs [
    brillo'
    "-I"
    "-u"
    "500000"
  ];

  # Suspend script
  suspendScript = pkgs.writeShellScript "idle-suspend-script" ''
    # check if any player has status "Playing"
    ${getExe pkgs.playerctl} -a status | ${getExe pkgs.ripgrep} Playing -q
    # only suspend if nothing is playing
    if [ $? == 1 ]; then
      ${getExe' pkgs.systemd "systemctl"} suspend
    fi
  '';

  # Keyboard backlight commands
  keyboardBacklightOff = escapeShellArgs [
    brightnessctl'
    "-sd"
    cfg.keyboardBacklight.device
    "set"
    "0"
  ];

  keyboardBacklightOn = escapeShellArgs [
    brightnessctl'
    "-rd"
    cfg.keyboardBacklight.device
  ];
in
{
  imports = lib.dot.scanPaths ./.;

  options.my.gui.desktop.idle = {
    default = mkOption {
      type = nullOr (enum [
        "hypridle"
        "swayidle"
        "shell"
      ]);
      default =
        if osConfig.dot.gui.desktop.default == "hyprland" then
          "hypridle"
        else if config.my.gui.desktop.shell.default == "noctalia" then
          "shell"
        else if osConfig.dot.gui.desktop.default == "niri" then
          "swayidle"
        else
          null;
      description = "The idle tool to use. Set to null to disable.";
    };

    timeout = mkOption {
      type = int;
      default = 600;
      description = "Base idle timeout in seconds.";
    };

    keyboardBacklight = {
      enable = mkEnableOption "keyboard backlight idle handling" // {
        default = true;
      };
      device = mkOption {
        type = str;
        default = "*::kbd_backlight";
        description = "Brightnessctl device name for the keyboard backlight.";
      };
    };

    suspend.enable = mkEnableOption "automatic suspend after the idle timeout" // {
      default = true;
    };

    # Internal command options
    commands = {
      lock = mkOption {
        type = str;
        default = shellLock;
        internal = true;
        readOnly = true;
        description = "Lock session command";
      };

      lockSession = mkOption {
        type = str;
        default = escapeShellArgs [
          loginctl'
          "lock-session"
        ];
        internal = true;
        readOnly = true;
        description = "Loginctl lock-session command";
      };

      screenOn = mkOption {
        type = nullOr str;
        default = screenOnCmd;
        internal = true;
        readOnly = true;
        description = "Turn on screen command";
      };

      screenOff = mkOption {
        type = nullOr str;
        default = screenOffCmd;
        internal = true;
        readOnly = true;
        description = "Turn off screen command";
      };

      dimScreen = mkOption {
        type = package;
        default = dimScreen;
        internal = true;
        readOnly = true;
        description = "Dim screen script";
      };

      restoreScreen = mkOption {
        type = str;
        default = restoreScreen;
        internal = true;
        readOnly = true;
        description = "Restore screen brightness command";
      };

      suspend = mkOption {
        type = package;
        default = suspendScript;
        internal = true;
        readOnly = true;
        description = "Suspend script";
      };

      keyboardBacklightOff = mkOption {
        type = str;
        default = keyboardBacklightOff;
        internal = true;
        readOnly = true;
        description = "Turn off keyboard backlight";
      };

      keyboardBacklightOn = mkOption {
        type = str;
        default = keyboardBacklightOn;
        internal = true;
        readOnly = true;
        description = "Turn on keyboard backlight";
      };
    };
  };
}
