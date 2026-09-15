{
  config,
  lib,
  ...
}:
# Only the selected emulator is installed and configured; terminal.emulator
# (terminals/terminal.nix) is the single switch.
lib.mkIf (config.terminal.emulator == "rio") {
  programs.rio = {
    enable = true;
    settings = {
      # On Linux rio defaults to spawning the shell with its own fork/exec
      # path, and that path takes no working directory at all: `--working-dir`
      # only reaches the pty through the std::process::Command path, which
      # rio picks on its own for `-e` commands (hence `rio -w /tmp -e sh -c
      # pwd` printing /tmp while a bare `rio -w /tmp` still opened in $HOME).
      # Turning the fork path off routes the bare shell through the same
      # spawn, so Mod+Return opens in the focused window's cwd again. Both
      # paths take the same shell program and args; login handling is
      # macOS-only in either.
      use-fork = false;

      # Font configuration
      # Rio's `size` is in pixels, not points; 16px ≈ 11pt at ~96 DPI.
      fonts = {
        size = 16;
        hinting = true;
        use-drawable-chars = true;
        features = [];

        regular = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 500; # Medium — a hair heavier than default 400
        };
        bold = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Normal";
          weight = 700;
        };
        italic = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Italic";
          weight = 500;
        };
        bold-italic = {
          family = "JetBrainsMonoNL Nerd Font";
          style = "Italic";
          weight = 700;
        };
      };

      # Text rendering
      line-height = 1.0; # >1.0 causes mouse selection offset (github.com/raphamorim/rio/issues/1101)
      padding-x = 4;

      # Auto-copy on select (no Ctrl+Shift+C needed)
      copy-on-select = true;

      # Cursor
      cursor = {
        shape = "block";
        blinking = false;
      };

      # Renderer
      renderer = {
        # `Webgpu` delegates to wgpu, which probes Vulkan → GL → fallback at startup.
        # (Rio 0.4.3 removed the old `Automatic` variant; `Webgpu` is the replacement.)
        # Forcing `Vulkan` segfaulted on launch under Wayland after upgrading to 0.4.0
        # (rio_window::wayland::EventLoop::poll_events_with_timeout). Switch back to
        # `Vulkan` once https://github.com/raphamorim/rio/issues/1530 settles.
        backend = "Webgpu";
        performance = "High";
        disable-unfocused-render = false; # true stops rendering when unfocused, hiding Helix/tail-like output until refocus
      };

      # Window settings
      window = {
        opacity = 1.0;
        blur = false;
      };

      # Disable quit confirmation
      confirm-before-quit = false;

      # Navigation — Plain since we use niri/zellij for splits/tabs
      navigation = {
        mode = "Plain";
        use-split = false;
      };

      # Theme - using base16 scheme to match Kitty
      colors = {
        background = "#${config.scheme.base00}";
        foreground = "#${config.scheme.base05}";
        cursor = "#${config.scheme.base05}";
        selection-background = "#${config.scheme.base02}";
        selection-foreground = "#${config.scheme.base05}";

        # ANSI colors (sourced from config.ansi — shared with kitty + helix)
        black = "#${config.ansi.black}";
        red = "#${config.ansi.red}";
        green = "#${config.ansi.green}";
        yellow = "#${config.ansi.yellow}";
        blue = "#${config.ansi.blue}";
        magenta = "#${config.ansi.magenta}";
        cyan = "#${config.ansi.cyan}";
        white = "#${config.ansi.white}";

        # Bright ANSI colors
        light-black = "#${config.ansi."bright-black"}";
        light-red = "#${config.ansi."bright-red"}";
        light-green = "#${config.ansi."bright-green"}";
        light-yellow = "#${config.ansi."bright-yellow"}";
        light-blue = "#${config.ansi."bright-blue"}";
        light-magenta = "#${config.ansi."bright-magenta"}";
        light-cyan = "#${config.ansi."bright-cyan"}";
        light-white = "#${config.ansi."bright-white"}";

        # UI elements
        tabs = "#${config.scheme.base00}";
        tabs-active = "#${config.scheme.base0D}";
        vi-cursor = "#${config.scheme.base05}";
      };
    };
  };
}
