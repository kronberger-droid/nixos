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
      floatingAppId = "floating_shell";
      # --working-dir was broken on the April 2026 fork build, hence the
      # cwdViaExec machinery. It was never broken for `-e` commands, only
      # for the bare shell, since rio's default fork path ignores the
      # directory; rio.nix sets `use-fork = false` so the flag now works for
      # both. Flip this back if a bump regresses it; niri.nix and nushell.nix
      # both still honour it.
      cwdViaExec = false;
    };
  };

  selectedConfig = terminalConfigs.${cfg.emulator};
in {
  options.terminal = {
    emulator = lib.mkOption {
      type = lib.types.enum ["rio"];
      default = "rio";
      description = ''
        The terminal emulator to use system-wide.
        This setting affects the terminal keybindings in niri,
        the bar's commands, and nushell aliases.
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
      floatingAppId = lib.mkDefault selectedConfig.floatingAppId;
      cwdViaExec = lib.mkDefault selectedConfig.cwdViaExec;
      cwdScript = "${config.xdg.configHome}/wm/cwd.sh";
    };

    # Lives here rather than with any one emulator so the compositor binds
    # depend on the terminal option alone.
    xdg.configFile."wm/cwd.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # Print working directory of the focused window, or $HOME.
        # Only uses cwd for terminals and file managers, not browsers/other apps.

        if [ -n "$NIRI_SOCKET" ] && [ -S "$NIRI_SOCKET" ]; then
            focused=$(${pkgs.niri}/bin/niri msg -j focused-window)
            app_id=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.app_id // empty')
            pid=$(echo "$focused" | ${pkgs.jq}/bin/jq -r '.pid')
        else
            echo "$HOME"
            exit 0
        fi

        relevant_apps="rio|foot|wezterm|ghostty|nemo|nautilus|thunar|yazi|ranger|helix|nvim|vim|emacs|code|zed"

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
