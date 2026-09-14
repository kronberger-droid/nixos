{
  pkgs,
  lib,
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
    .${
      primaryCompositor
    };

  # Wrapper that redirects stderr so TTY stays clean on login.
  # Warnings/errors still readable at /tmp/${sessionBin}.log.
  sessionWrapper = pkgs.writeShellScript "${sessionBin}-quiet" ''
    exec ${sessionBin} 2>/tmp/${sessionBin}.log
  '';

  # Desktop entry so tuigreet shows a clean name instead of the Nix store path.
  compositorName = lib.toUpper (lib.substring 0 1 primaryCompositor) + lib.substring 1 (-1) primaryCompositor;

  quietSessions = pkgs.runCommand "quiet-wayland-sessions" {} ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/${primaryCompositor}.desktop <<EOF
    [Desktop Entry]
    Name=${compositorName}
    Exec=${sessionWrapper}
    Type=Application
    EOF
  '';
in {
  services.greetd = {
    enable = true;
    # TUI-aware unit hardening: hangs up + deallocates tty1 before tuigreet
    # opens it, and redirects greetd's stderr to the journal. Stops the
    # boot-log tail and stray warnings from bleeding into the greeter UI.
    useTextGreeter = true;
    settings = {
      default_session = {
        # Must stay a single-line string: greetd's TOML parser rejects the
        # multi-line ('''…''') literal that nixpkgs' toml generator now emits,
        # failing with "expected equals sign" and leaving a blank greeter.
        command = lib.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--asterisks"
          "--user-menu"
          "--cmd ${sessionWrapper}"
          "--remember"
          "--remember-user-session"
          # Only the primary compositor's session. Sway used to be listed as a
          # fallback on every host, but its home-manager config is now gated
          # on compositor.primary, so on a niri host that entry would have
          # started a stock sway with no terminal bound: not a fallback.
          "--sessions ${quietSessions}/share/wayland-sessions"
        ];
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    ${sessionBin}
  '';
}
