{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.terminal;

  # Terminal-specific configurations
  terminalConfigs = {
    rio = {
      bin = "${pkgs.rio}/bin/rio";
      execFlag = "-e";
      workingDirFlag = "--working-dir";
      appIdFlag = "--app-id";
      hasKittens = false;
      floatingAppId = "floating_shell";
      # --working-dir was broken on the April 2026 fork build, hence the
      # cwdViaExec machinery. Re-tested 2026-09-15 on the upstream-main
      # build: `rio --working-dir /tmp -e sh -c pwd` prints /tmp, so the
      # flag is used directly again. Flip this back if a bump regresses it;
      # niri.nix and nushell.nix both still honour it.
      cwdViaExec = false;
    };

    kitty = {
      bin = "${pkgs.kitty}/bin/kitty";
      execFlag = "-e";
      workingDirFlag = "--working-directory";
      appIdFlag = "--app-id";
      hasKittens = true;
      floatingAppId = "floating_shell";
      cwdViaExec = false;
    };

    alacritty = {
      bin = "${pkgs.alacritty}/bin/alacritty";
      execFlag = "-e";
      workingDirFlag = "--working-directory";
      appIdFlag = "--class";
      hasKittens = false;
      floatingAppId = "floating_shell";
      cwdViaExec = false;
    };
  };

  selectedConfig = terminalConfigs.${cfg.emulator};
in {
  options.terminal = {
    emulator = lib.mkOption {
      type = lib.types.enum ["rio" "kitty" "alacritty"];
      default = "kitty";
      description = ''
        The terminal emulator to use system-wide.
        This setting affects all terminal keybindings in Sway,
        Waybar commands, and nushell aliases.
      '';
    };

    # Exposed attributes that other modules will reference
    bin = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Path to the terminal emulator binary";
    };

    execFlag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Flag to execute a command (e.g., '-e')";
    };

    workingDirFlag = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Flag to set working directory";
    };

    appIdFlag = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      description = "Flag to set application ID (null if not supported)";
    };

    hasKittens = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      description = "Whether this terminal supports kitty kittens";
    };

    floatingAppId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      description = "App ID value for floating windows (null if not supported)";
    };

    cwdViaExec = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      description = "Use -e cd workaround instead of --working-dir flag";
    };

    cwdScript = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Path of a script that prints the working directory of the focused
        window (or $HOME). The compositor keybindings for "open a terminal /
        file manager here" call it. Terminal-agnostic, which is why it lives
        in this module and not with any one emulator.
      '';
    };
  };

  config = {
    terminal = {
      bin = lib.mkDefault selectedConfig.bin;
      execFlag = lib.mkDefault selectedConfig.execFlag;
      workingDirFlag = lib.mkDefault selectedConfig.workingDirFlag;
      appIdFlag = lib.mkDefault selectedConfig.appIdFlag;
      hasKittens = lib.mkDefault selectedConfig.hasKittens;
      floatingAppId = lib.mkDefault selectedConfig.floatingAppId;
      cwdViaExec = lib.mkDefault selectedConfig.cwdViaExec;
      cwdScript = "${config.xdg.configHome}/wm/cwd.sh";
    };

    # Used to be kitty/cwd.sh inside terminals/kitty.nix, so niri and sway
    # both depended on the kitty module even on rio hosts.
    xdg.configFile."wm/cwd.sh" = let
      # The niri branch interpolates ${pkgs.niri} (the source-built fork) and
      # is only emitted when niri is the primary compositor. Note the sway
      # branch below always references ${pkgs.sway} for swaymsg, as do
      # rofi.nix and session-services.nix, so sway itself is in every
      # closure; the gate here only keeps a sway-primary host from also
      # building the niri fork for a script branch it never takes.
      niriPrimary = config.compositor.primary == "niri";
    in {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # Print working directory of the focused window, or $HOME.
        # Only uses cwd for terminals and file managers, not browsers/other apps.
        # Supports both sway and niri.

        ${lib.optionalString niriPrimary ''
          if [ -n "$NIRI_SOCKET" ] && [ -S "$NIRI_SOCKET" ]; then
              focused=$(${pkgs.niri}/bin/niri msg -j focused-window)
              app_id=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.app_id // empty')
              pid=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.pid')
          el''}if [ -n "$SWAYSOCK" ] && [ -S "$SWAYSOCK" ]; then
            focused=$(${pkgs.sway}/bin/swaymsg -t get_tree | ${pkgs.jq}/bin/jq -r \
                  '.. | select(.type?) | select(.type=="con") | select(.focused==true)')
            app_id=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.app_id // empty')
            pid=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.pid')
        else
            echo "$HOME"
            exit 0
        fi

        relevant_apps="kitty|rio|foot|alacritty|wezterm|ghostty|nemo|nautilus|thunar|yazi|ranger|helix|nvim|vim|emacs|code|zed"

        if [[ "$app_id" =~ ^($relevant_apps) ]]; then
            ppid=$(${pkgs.procps}/bin/pgrep --newest --parent "$pid")
            cwd=$(${pkgs.uutils-coreutils-noprefix}/bin/readlink "/proc/''${ppid}/cwd" 2>/dev/null || true)
            echo "''${cwd:-$HOME}"
        else
            echo "$HOME"
        fi
      '';
    };
  };
}
