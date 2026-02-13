{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.programs.arrabbiata-tui;
  arrabbiata = inputs.arrabbiata-tui.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  options.programs.arrabbiata-tui = {
    enable = lib.mkEnableOption "arrabbiata-tui pomodoro timer";

    configFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a JSON file containing arrabbiata-tui configuration.
        Expected keys: apiUrl, userId, fallbackUserId.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "arrabbiata-tui" ''
        export ARRABBIATA_API_URL="$(${pkgs.jq}/bin/jq -r '.apiUrl' ${cfg.configFile})"
        export ARRABBIATA_USER_ID="$(${pkgs.jq}/bin/jq -r '.userId' ${cfg.configFile})"
        export ARRABBIATA_FALLBACK_USER_ID="$(${pkgs.jq}/bin/jq -r '.fallbackUserId' ${cfg.configFile})"
        exec ${arrabbiata}/bin/arrabbiata-tui "$@"
      '')
    ];
  };
}
