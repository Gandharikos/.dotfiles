{
  system.defaults.CustomUserPreferences = {
    # Enable “Displays have separate Spaces”. The preference key is inverse:
    # false means Spaces do not span displays.
    "com.apple.spaces"."spans-displays" = false;

    "com.apple.WindowManager" = {
      # Click wallpaper to reveal desktop
      EnableStandardClickToShowDesktop = 0;

      # Show items on desktop
      StandardHideDesktopIcons = 0;

      # Do not hide items on desktop & stage manager
      HideDesktop = 0;
      StageManagerHideWidgets = 0;
      StandardHideWidgets = 0;
    };
  };
}
