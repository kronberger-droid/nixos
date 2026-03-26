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

  # Wrapper that redirects stderr so TTY stays clean on login.
  # Warnings/errors still readable at /tmp/niri-session.log.
  sessionWrapper = pkgs.writeShellScript "${sessionBin}-quiet" ''
    exec ${sessionBin} 2>/tmp/niri-session.log
  '';

  # Desktop entry so tuigreet shows a clean name instead of the Nix store path.
  quietSessions = pkgs.runCommand "quiet-wayland-sessions" {} ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/niri.desktop <<EOF
    [Desktop Entry]
    Name=Niri
    Exec=${sessionWrapper}
    Type=Application
    EOF
  '';
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
          --cmd ${sessionWrapper} \
          --remember \
          --remember-user-session \
          --sessions ${quietSessions}/share/wayland-sessions:${pkgs.sway}/share/wayland-sessions
        '';
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    niri-session
    sway
  '';
}
