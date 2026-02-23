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

  # Wrap niri-session to suppress TTY output (env import messages) that
  # otherwise flashes between tuigreet exiting and the compositor rendering.
  # sway doesn't need this because it starts directly as the compositor.
  sessionCommand =
    if primaryCompositor == "niri"
    then
      pkgs.writeShellScript "niri-session-quiet" ''
        exec ${sessionBin} >/dev/null 2>&1
      ''
    else sessionBin;
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
  '';
}
