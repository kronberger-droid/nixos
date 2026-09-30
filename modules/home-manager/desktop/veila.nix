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
  # that theme shows has to be switched off here, not merely left out. Tables
  # merge key by key but arrays replace, so `backdrop` below also drops the
  # theme's now_playing backdrop.
  #
  # Layout: a frosted card in the middle holding clock, password field and
  # battery. Offsets are relative to the screen centre.
  xdg.configFile."veila/config.toml".source = toml.generate "veila.toml" {
    background = {
      mode = "file";
      path = "${./sway/deathpaper.jpg}";
      blur_strength = 14;
      dim_strength = 15;
    };
    battery.enabled = true;
    weather.enabled = false;
    visuals = {
      date.enabled = false;
      avatar.enabled = false;
      username.enabled = false;
      keyboard.enabled = false;
      placeholder.enabled = false;
      eye.enabled = false;
      now_playing.enabled = false;
      backdrop = [
        {
          name = "card";
          mode = "blur";
          blur_strength = 18;
          color = "#${c.base00}59";
          border_color = "#${c.base05}14";
          border_width = 1;
          width = 380;
          height = 230;
          radius = 28;
          halign = "center";
          valign = "center";
          x = 0;
          y = 0;
        }
      ];
      clock = {
        enabled = true;
        format = "24h";
        font_weight = 200;
        font_size = 52;
        color = "#${c.base05}8C";
        halign = "center";
        valign = "center";
        x = 0;
        y = -50;
      };
      input = {
        placeholder = "";
        background_color = "#${c.base05}0F";
        border_color = "#${c.base05}1F";
        border_width = 1;
        mask_color = "#${c.base05}";
        width = 300;
        height = 44;
        radius = 22;
        halign = "center";
        valign = "center";
        x = 0;
        y = 30;
      };
      battery = {
        enabled = true;
        background_color = "#${c.base00}00";
        background_size = 32;
        color = "#${c.base05}8C";
        size = 16;
        halign = "center";
        valign = "center";
        x = 0;
        y = 85;
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
