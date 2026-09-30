{
  config,
  pkgs,
  ...
}: let
  c = config.scheme;
  toml = pkgs.formats.toml {};
in {
  # Trial replacement for swaylock-effects. veila speaks
  # wp_fractional_scale_v1 + wp_viewporter, so it renders at the output's real
  # scale and needs none of the per-host `scale` swaylock.nix carries.
  #
  # Unlike swaylock it is a client of a long-running daemon: `veila lock` only
  # asks veilad to lock, so veilad has to be up before swayidle fires. The
  # PAM service lives in modules/system/desktop/desktop.nix; without
  # /etc/pam.d/veila it falls back to system-auth, which NixOS lacks.
  home.packages = [pkgs.veila];

  # A user config is layered over the bundled default theme, so every widget
  # that theme shows has to be switched off here, not merely left out.
  xdg.configFile."veila/config.toml".source = toml.generate "veila.toml" {
    background = {
      mode = "file";
      path = "${./sway/deathpaper.jpg}";
    };
    battery.enabled = false;
    weather.enabled = false;
    visuals = {
      clock.enabled = false;
      date.enabled = false;
      avatar.enabled = false;
      username.enabled = false;
      keyboard.enabled = false;
      battery.enabled = false;
      placeholder.enabled = false;
      eye.enabled = false;
      input = {
        placeholder = "";
        background_color = "#${c.base00}CC";
        border_color = "#${c.base00}";
        border_width = 2;
        mask_color = "#${c.base05}";
        width = 280;
        height = 48;
        radius = 24;
        y = 0;
      };
      status.rejected_color = "#${c.base08}";
      caps_lock.color = "#${c.base0F}";
    };
  };

  systemd.user.services.veilad = {
    Unit = {
      Description = "Veila screen locker daemon";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.veila}/bin/veilad";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
