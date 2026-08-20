{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib.types)
    enum
    addCheck
    str
    ;
  cfg = config.dot.keyboard;
  letters = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz";
  upperLetters = lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  char = addCheck str (s: builtins.stringLength s == 1);
  mkLetterOption =
    letter:
    mkOption {
      type = char;
      default = letter;
      description = "Single-letter option for ${letter}.";
    };
in
{
  options.dot.keyboard = {
    # Note: I need to use general keyboard layout for my laptop and for Enterprise desktop
    layout = mkOption {
      type = enum [
        "qwerty"
        "colemak"
      ];
      default = "colemak";
      description = "The keyboard layout to use";
    };

    backend = mkOption {
      type = lib.types.nullOr (enum [
        "kanata"
        "keyd"
        "karabiner"
      ]);
      default = null;
      description = "The keyboard backend to use";
    };

    keys = lib.genAttrs (letters ++ upperLetters) mkLetterOption;
  };

  options.dot.services = {
    kanata = {
      enable = mkOption {
        type = lib.types.bool;
        default = cfg.backend == "kanata";
        internal = true;
        readOnly = true;
        description = "Whether to enable Kanata keyboard remapping";
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.backend == "karabiner" -> pkgs.stdenv.hostPlatform.isDarwin;
          message = "Karabiner backend is only supported on Darwin (macOS).";
        }
        {
          assertion = cfg.backend == "keyd" -> pkgs.stdenv.hostPlatform.isLinux;
          message = "Keyd backend is only supported on Linux.";
        }
      ];
    }
    (mkIf (cfg.layout == "colemak") {
      dot.keyboard.keys = {
        h = "n";
        j = "e";
        k = "i";
        l = "o";
        H = "N";
        J = "E";
        K = "I";
        L = "O";
        n = "k";
        e = "j";
        o = "l";
        i = "h";
        N = "K";
        E = "J";
        I = "H";
        O = "L";
      };
    })
  ];
}
