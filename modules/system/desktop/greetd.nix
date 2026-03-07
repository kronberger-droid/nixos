{
  pkgs,
  primaryCompositor,
  ...
}: let
  # Map compositor to proper session launcher.
  # niri-session activates graphical-session.target through systemd's session API;
  # bare "niri" cannot (RefuseManualStart).
  sessionBin =
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
          --cmd ${sessionBin} \
          --remember \
          --remember-user-session \
          --sessions ${pkgs.niri}/share/wayland-sessions:${pkgs.sway}/share/wayland-sessions
        '';
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    niri-session
    sway
  '';
}
