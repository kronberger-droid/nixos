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
      cwdViaExec = true; # --working-dir is broken; use -e cd workaround
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
  };

  config.terminal = {
    bin = lib.mkDefault selectedConfig.bin;
    execFlag = lib.mkDefault selectedConfig.execFlag;
    workingDirFlag = lib.mkDefault selectedConfig.workingDirFlag;
    appIdFlag = lib.mkDefault selectedConfig.appIdFlag;
    hasKittens = lib.mkDefault selectedConfig.hasKittens;
    floatingAppId = lib.mkDefault selectedConfig.floatingAppId;
    cwdViaExec = lib.mkDefault selectedConfig.cwdViaExec;
  };
}
