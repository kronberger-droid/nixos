{
  pkgs,
  primaryCompositor,
  ...
}: let
  # Map compositor to proper session launcher.
  # niri-session activates graphical-session.target through systemd's session API;
  # bare "niri" cannot (RefuseManualStart).
  sessionCommand =
    {
      niri = "niri-session";
      sway = "sway";
    }
    .${primaryCompositor};
in {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
          --time \
          --asterisks \
          --user-menu \
          --cmd ${sessionCommand} \
          --remember \
          --remember-user-session \
        '';
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    niri-session
    sway
    nushell
  '';
}
