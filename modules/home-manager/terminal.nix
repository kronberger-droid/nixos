{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.terminal;

  # Terminal-specific configurations
  terminalConfigs = {
    rio = {
      bin = "${pkgs.rio}/bin/rio";
      execFlag = "-e";
      workingDirFlag = "--working-dir";
      appIdFlag = null;
      hasKittens = false;
      floatingAppId = null;
    };

    kitty = {
      bin = "${pkgs.kitty}/bin/kitty";
      execFlag = "-e";
      workingDirFlag = "--working-directory";
      appIdFlag = "--app-id";
      hasKittens = true;
      floatingAppId = "floating_shell";
    };

    alacritty = {
      bin = "${pkgs.alacritty}/bin/alacritty";
      execFlag = "-e";
      workingDirFlag = "--working-directory";
      appIdFlag = "--class";
      hasKittens = false;
      floatingAppId = "floating_shell";
    };
  };

  selectedConfig = terminalConfigs.${cfg.emulator};
in {
  options.terminal = {
    emulator = mkOption {
      type = types.enum ["rio" "kitty" "alacritty"];
      default = "rio";
      description = ''
        The terminal emulator to use system-wide.
        This setting affects all terminal keybindings in Sway,
        Waybar commands, and nushell aliases.
      '';
    };

    # Exposed attributes that other modules will reference
    bin = mkOption {
      type = types.str;
      readOnly = true;
      description = "Path to the terminal emulator binary";
    };

    execFlag = mkOption {
      type = types.str;
      readOnly = true;
      description = "Flag to execute a command (e.g., '-e')";
    };

    workingDirFlag = mkOption {
      type = types.str;
      readOnly = true;
      description = "Flag to set working directory";
    };

    appIdFlag = mkOption {
      type = types.nullOr types.str;
      readOnly = true;
      description = "Flag to set application ID (null if not supported)";
    };

    hasKittens = mkOption {
      type = types.bool;
      readOnly = true;
      description = "Whether this terminal supports kitty kittens";
    };

    floatingAppId = mkOption {
      type = types.nullOr types.str;
      readOnly = true;
      description = "App ID value for floating windows (null if not supported)";
    };
  };

  config.terminal = {
    bin = mkDefault selectedConfig.bin;
    execFlag = mkDefault selectedConfig.execFlag;
    workingDirFlag = mkDefault selectedConfig.workingDirFlag;
    appIdFlag = mkDefault selectedConfig.appIdFlag;
    hasKittens = mkDefault selectedConfig.hasKittens;
    floatingAppId = mkDefault selectedConfig.floatingAppId;
  };
}
