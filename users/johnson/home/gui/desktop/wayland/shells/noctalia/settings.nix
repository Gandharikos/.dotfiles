{
  inputs,
  config,
  osConfig,
  keys,
  lib,
  avatar,
  wallpaper,
  wallpaperDirectory,
}:
let
  panelAttachedPlacement =
    if osConfig.dot.gui.desktop.default == "hyprland" then "floating" else "attached";
in
{
  shell = {
    ui_scale = 1;
    corner_radius_scale = 1.0;
    lang = "";
    time_format = "{:%H:%M}";
    date_format = "%A, %x";
    telemetry_enabled = true;
    font_family = "CaskaydiaCove Nerd Font Mono";
    setup_wizard_enabled = false;
    settings_show_advanced = true;
    app_icon_colorize = true;
    avatar_path = lib.optionalString (avatar != null) (toString avatar);
    niri_overview_type_to_launch_enabled = true;
    offline_mode = false;
    polkit_agent = true;
    screen_time_enabled = true;
    clipboard_enabled = true;
    clipboard_history_max_entries = 1000;
    clipboard_confirm_clear_history = true;
    clipboard_auto_paste = "auto";
    launch_apps_as_systemd_services = true;
    animation = {
      enabled = true;
      speed = 1;
    };
    shadow = {
      direction = "down_right";
      alpha = 0.55;
    };
    panel = {
      transparency_mode = "glass";
      borders = true;
      shadow = true;
      launcher_placement = "floating";
      clipboard_placement = panelAttachedPlacement;
      control_center_placement = panelAttachedPlacement;
      wallpaper_placement = panelAttachedPlacement;
      session_placement = panelAttachedPlacement;
      open_near_click_control_center = false;
      open_near_click_launcher = false;
      open_near_click_clipboard = false;
      open_near_click_wallpaper = false;
      open_near_click_session = false;
      launcher_categories = true;
      launcher_show_icons = true;
      launcher_compact = true;
    };
    screen_corners = {
      enabled = true;
      size = 32;
    };
    screenshot = {
      save_to_file = true;
      copy_to_clipboard = true;
      freeze_screen = true;
      directory = config.xdg.userDirs.extraConfig.SCREENSHOTS;
      filename_pattern = "Screenshot_%Y-%m-%d_%H-%M-%S.png";
    };
    mpris.blacklist = [ ];
  };

  wallpaper = {
    enabled = true;
    fill_mode = "crop";
    fill_color = "#000000";
    transition = [
      "fade"
      "disc"
      "stripes"
      "wipe"
      "honeycomb"
      "zoom"
    ];
    transition_duration = 1500;
    edge_smoothness = 0.05;
    transition_on_startup = true;
    directory = wallpaperDirectory;
    directory_light = "";
    directory_dark = "";
    per_monitor_directories = false;
    automation = {
      enabled = true;
      interval_seconds = 5400;
      order = "random";
      recursive = true;
    };
  }
  // lib.optionalAttrs (wallpaper != null) {
    default.path = toString wallpaper;
    last.path = toString wallpaper;
    monitors."eDP-1".path = toString wallpaper;
  };

  theme = {
    builtin = "Tokyo-Night";
    wallpaper_scheme = lib.mkDefault "m3-tonal-spot";
    templates = {
      enable_builtin_templates = true;
      builtin_ids = [ ];
      enable_community_templates = true;
      community_ids = [ ];
    };
  };

  backdrop = {
    enabled = true;
    blur_intensity = 0.3;
    tint_intensity = 0.3;
  };

  notification = {
    enable_daemon = true;
    show_app_name = true;
    show_actions = true;
    position = "top_right";
    layer = "overlay";
    scale = 1;
    background_opacity = 1;
    offset_x = 20;
    offset_y = 8;
    monitors = [ ];
    collapse_on_dismiss = true;
  };

  osd = {
    position = "top_right";
    orientation = "horizontal";
    scale = 1;
    background_opacity = 1;
    offset_x = 20;
    offset_y = 8;
    monitors = [ ];
    kinds = {
      volume = true;
      volume_output = true;
      volume_input = true;
      brightness = true;
      wifi = true;
      bluetooth = true;
      power_profile = true;
      caffeine = true;
      dnd = true;
      lock_keys = true;
      keyboard_layout = true;
    };
  };

  lockscreen = {
    blurred_desktop = true;
    blur_intensity = 1.0;
    tint_intensity = 0.5;
    monitors = [ ];
  };

  lockscreen_widgets = {
    enabled = true;
    schema_version = 2;
    widget_order = [
      "lockscreen-login-box@eDP-1"
      "lockscreen-widget-0000000000000001"
      "lockscreen-widget-0000000000000002"
      "lockscreen-widget-0000000000000003"
    ];
    grid = {
      cell_size = 16;
      major_interval = 4;
      visible = true;
    };
    widget = {
      "lockscreen-login-box@eDP-1" = {
        type = "login_box";
        output = "eDP-1";
        cx = 960.0;
        cy = 1077.0;
        box_width = 0.0;
        box_height = 0.0;
        rotation = 0.0;
        settings = {
          background_color = "surface_variant";
          background_opacity = 0.88;
          background_radius = 12.0;
          input_opacity = 1.0;
          input_radius = 6.0;
          show_login_button = true;
        };
      };
      "lockscreen-widget-0000000000000001" = {
        type = "clock";
        output = "eDP-1";
        cx = 960.0;
        cy = 439.5;
        box_width = 0.0;
        box_height = 0.0;
        rotation = 0.0;
      };
      "lockscreen-widget-0000000000000002" = {
        type = "fancy_audio_visualizer";
        output = "eDP-1";
        cx = 960.0;
        cy = 802.0;
        box_width = 0.0;
        box_height = 0.0;
        rotation = 0.0;
        settings.background = false;
      };
      "lockscreen-widget-0000000000000003" = {
        type = "weather";
        output = "eDP-1";
        cx = 960.0;
        cy = 538.0;
        box_width = 0.0;
        box_height = 0.0;
        rotation = 0.0;
      };
    };
  };

  system.monitor = {
    enabled = true;
    cpu_poll_seconds = 2;
    gpu_poll_seconds = 5;
    memory_poll_seconds = 2;
    network_poll_seconds = 3;
    disk_poll_seconds = 10;
    cpu_usage_activity_threshold = 80;
    cpu_usage_critical_threshold = 90;
    cpu_temp_activity_threshold = 80;
    cpu_temp_critical_threshold = 90;
    gpu_temp_activity_threshold = 80;
    gpu_temp_critical_threshold = 90;
    ram_pct_activity_threshold = 80;
    ram_pct_critical_threshold = 90;
    swap_pct_activity_threshold = 80;
    swap_pct_critical_threshold = 90;
    disk_pct_activity_threshold = 80;
    disk_pct_critical_threshold = 90;
  };

  weather = {
    enabled = true;
    effects = true;
    refresh_minutes = 30;
    unit = "celsius";
  };

  audio = {
    enable_overdrive = false;
    enable_sounds = true;
    sound_volume = 1.0;
    volume_change_sound = "${config.programs.noctalia.package}/share/noctalia/assets/sounds/volume-change.wav";
    notification_sound = "${config.programs.noctalia.package}/share/noctalia/assets/sounds/notification.wav";
  };

  brightness = {
    enable_ddcutil = false;
    ignore_mmids = [ ];
  };

  battery.warning_threshold = 20;

  calendar = {
    enabled = true;
    refresh_minutes = 30;
    account.google = {
      type = "google";
      name = "Google";
      color = "#4285F4";
    };
  };

  nightlight = {
    enabled = false;
    force = false;
    temperature_day = 6500;
    temperature_night = 4000;
  };

  location = {
    auto_locate = true;
    address = "";
    sunrise = "06:30";
    sunset = "18:30";
  };

  keybinds = {
    validate = [
      "return"
      "kp_enter"
    ];
    cancel = [ "escape" ];
    left = [
      "left"
      "ctrl+${keys.H}"
    ];
    down = [
      "down"
      "ctrl+${keys.J}"
    ];
    up = [
      "up"
      "ctrl+${keys.K}"
    ];
    right = [
      "right"
      "ctrl+${keys.L}"
    ];
  };

  bar = {
    order = [ "default" ];
    default = {
      position = "top";
      enabled = true;
      auto_hide = false;
      reserve_space = true;
      layer = "top";
      thickness = 34;
      background_opacity = 0;
      border = "outline";
      border_width = 0;
      radius = 15;
      margin_ends = 6;
      margin_edge = 6;
      padding = 4;
      widget_spacing = 8;
      shadow = true;
      contact_shadow = true;
      panel_overlap = 0;
      scale = 1.1;
      font_weight = 500;
      capsule = true;
      capsule_fill = "surface_variant";
      capsule_padding = 8;
      capsule_opacity = 0.0;
      start = [
        "group:g5"
        "group:g7"
      ];
      center = [
        "group:g6"
      ];
      end = [
        "group:g8"
        "group:g1"
        "group:g4"
        "group:g2"
        "group:g3"
      ];
      capsule_group = [
        {
          id = "g1";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 8.0;
          members = [
            "wallpaper"
            "screenshot"
            "noctalia/screen_recorder:recorder"
          ];
        }
        {
          id = "g2";
          border = "";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 8.0;
          members = [
            "volume"
            "brightness"
            "network"
            "bluetooth"
            "battery"
          ];
        }
        {
          id = "g3";
          border = "";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 8.0;
          members = [
            "tray"
            "notifications"
            "control-center"
            "session"
          ];
        }
        {
          id = "g4";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 8.0;
          members = [
            "power_profile"
            "nightlight"
            "caffeine"
            "clipboard"
          ];
        }
        {
          id = "g5";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 3.0;
          members = [
            "launcher"
            "workspaces"
            "active_window"
            "taskbar"
          ];
        }
        {
          id = "g6";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 3.0;
          members = [
            "media"
            "clock"
            "weather"
          ];
        }
        {
          id = "g7";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 3.0;
          members = [
            "sysmon"
            "ram"
            "temp"
          ];
        }
        {
          id = "g8";
          fill = "surface_variant";
          opacity = 0.0;
          padding = 8.0;
          members = [
            "cat"
            "audio_visualizer"
          ];
        }
      ];
    };
  };

  dock = {
    enabled = false;
    position = "bottom";
    active_monitor_only = true;
    icon_size = 48;
    main_axis_padding = 16;
    cross_axis_padding = 8;
    item_spacing = 6;
    background_opacity = 1;
    radius = 16;
    margin_ends = 0;
    margin_edge = 8;
    shadow = false;
    show_running = true;
    auto_hide = true;
    reserve_space = false;
    active_scale = 1;
    inactive_scale = 0.6;
    magnification = true;
    magnification_scale = 1.45;
    active_opacity = 1;
    inactive_opacity = 0.6;
    show_dots = false;
    show_instance_count = true;
    launcher_position = "none";
    launcher_icon = "grid-dots";
    pinned = [ ];
    monitors = [ ];
  };

  desktop_widgets = {
    enabled = true;
    schema_version = 2;
    widget_order = [ ];
    grid = {
      cell_size = 16;
      major_interval = 4;
      visible = true;
    };
    widget = { };
  };

  control_center = {
    sidebar = "compact";
    sidebar_section = "compact";
    shortcuts = [
      { type = "wifi"; }
      { type = "bluetooth"; }
      { type = "caffeine"; }
      { type = "nightlight"; }
      { type = "notification"; }
      { type = "noctalia/screen_recorder:toggle"; }
    ];
  };

  plugins = {
    source = [
      {
        name = "dotfiles";
        kind = "path";
        location = toString ./plugins;
        auto_update = false;
      }
      {
        name = "official";
        kind = "path";
        location = toString inputs."noctalia-official-plugins";
        auto_update = false;
      }
      {
        name = "community";
        kind = "git";
        location = "https://github.com/noctalia-dev/community-plugins";
        auto_update = true;
      }
    ];
    enabled = [
      "noctalia/bongocat"
      "noctalia/screen_recorder"
      "noctalia/translator"
    ];
  };

  plugin_settings."noctalia/screen_recorder" = {
    video_source = "portal";
    directory = config.xdg.userDirs.extraConfig.RECORDINGS;
    filename_pattern = "recording_%Y%m%d_%H%M%S";
    frame_rate = 60;
    video_codec = "h264";
    quality = "very_high";
    resolution = "original";
    audio_source = "default_output";
    audio_codec = "opus";
    show_cursor = true;
    color_range = "limited";
    copy_to_clipboard = false;
    hide_inactive = false;
    replay_enabled = false;
    replay_duration = 30;
    replay_storage = "ram";
    restore_portal = false;
  };

  widget = {
    active_window = {
      max_length = 160;
      title_scroll = "always";
    };
    audio_visualizer = {
      bands = 60;
      color_2 = "secondary";
      width = 120.0;
    };
    battery = {
      hide_when_full = true;
      hide_when_plugged = true;
    };
    cat = {
      type = "noctalia/bongocat:cat";
      input_device = "/dev/input/event17";
      audio_spectrum = true;
      rave_mode = true;
      tappy_mode = true;
      use_mpris_filter = true;
    };
    clock = {
      anchor = true;
      font_weight = 800;
      scale = 1.3;
      tooltip_format = "{:%Y-%m-%d %A %H:%M:%S %Z}";
    };
    launcher = {
      anchor = false;
      custom_image = toString (lib.dot.getFile ".assets/nixos_logo.png");
      glyph = "ghost-3";
      scale = 1.3;
    };

    media = {
      hide_when_no_media = true;
      title_scroll = "always";
    };
    input_volume.show_label = false;
    network.show_label = false;
    notifications.hide_when_no_unread = true;
    session = {
      color = "error";
      scale = 1.3;
    };
    tray.drawer = true;
    weather.show_condition = false;
    workspaces.display = "none";
  };
}
