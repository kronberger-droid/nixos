{
  pkgs,
  config,
  lib,
  osConfig ? null,
  ...
}: {
  programs.spotify-player = {
    enable = true;
    settings = {
      theme = "base16";
      # Own Spotify app; the shared default ID is constantly rate limited.
      client_id = "555a562055744436a721cc2662b9b3f6";
      # Playlist GETs default to ncspot's shared ID, which hits the same rate
      # limit. Send them through ours; a 4xx still falls back to ncspot.
      ncspot_only_get_endpoints = [];
      # Audio comes from the daemon below; the popup TUI only remote-controls
      # it, so closing the popup does not stop playback.
      enable_streaming = "DaemonOnly";
      # The TUI would otherwise notify on the same track changes as well.
      notify_streaming_only = true;
      # Every host's daemon would otherwise register as `spotify-player`, and
      # the popup's `connect --name` (ironbar/nu/spotify.nu) takes the first match.
      device.name = "spotify-player-${osConfig.networking.hostName or "local"}";
      copy_command = {
        command = "${pkgs.wl-clipboard-rs}/bin/wl-copy";
        args = [];
      };
    };
    themes = [
      (with config.scheme; {
        name = "base16";
        palette = {
          foreground = "#${base05}";
          black = "#${base00}";
          red = "#${base08}";
          green = "#${base0B}";
          yellow = "#${base0A}";
          blue = "#${base0D}";
          magenta = "#${base0E}";
          cyan = "#${base0C}";
          white = "#${base05}";
          bright_black = "#${base03}";
          bright_red = "#${base08}";
          bright_green = "#${base0B}";
          bright_yellow = "#${base0A}";
          bright_blue = "#${base0D}";
          bright_magenta = "#${base0E}";
          bright_cyan = "#${base0C}";
          bright_white = "#${base07}";
        };
        component_style = {
          block_title.fg = "#${base06}";
          border.fg = "#${base03}";
          playback_track = {
            fg = "#${base06}";
            modifiers = ["Bold"];
          };
          playback_artists.fg = "#${base05}";
          playback_album.fg = "#${base04}";
          playback_metadata.fg = "#${base03}";
          playback_progress_bar = {
            fg = "#${base0F}";
            bg = "#${base01}";
          };
          current_playing = {
            fg = "#${base0B}";
            modifiers = ["Bold"];
          };
          page_desc.fg = "#${base04}";
          table_header.fg = "#${base0D}";
          selection = {
            fg = "#${base06}";
            bg = "#${base02}";
          };
        };
      })
    ];
  };

  # The Spotify Connect device that plays audio and serves MPRIS. It used to
  # be the TUI itself inside a zellij session, but zellij drops the kitty
  # graphics protocol, and with it the cover art.
  systemd.user.services.spotify-player = {
    Unit = {
      Description = "spotify-player daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
      X-Restart-Triggers = ["${config.xdg.configFile."spotify-player/app.toml".source}"];
    };
    Service = {
      # `--daemon` forks through the daemonize crate and the parent exits.
      Type = "forking";
      ExecStart = "${lib.getExe config.programs.spotify-player.package} --daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  # spotifyd is a Spotify Connect target (lets other devices cast here);
  # spotify-player streams on its own and does not need it. Disabled until
  # the agenix secret for password_cmd is set up.
  services.spotifyd = {
    enable = false;
    settings.global = {
      username = "martinkronberger";
      password_cmd = "${pkgs.uutils-coreutils-noprefix}/bin/cat /run/secrets/spotify-password";
      device_name = "nixos";
      backend = "pulseaudio";
      bitrate = 320;
      device_type = "computer";
      # Disable Spotify Connect discovery; only spotify-player is used locally
      disable_discovery = true;
    };
  };
}
