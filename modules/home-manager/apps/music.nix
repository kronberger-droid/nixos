{
  pkgs,
  config,
  ...
}: {
  home.packages = [pkgs.ncspot];

  # spotifyd is a Spotify Connect target (lets other devices cast here);
  # ncspot connects to Spotify directly and does not need it. Disabled until
  # the agenix secret for password_cmd is set up.
  services.spotifyd = {
    enable = false;
    settings.global = {
      username = "martinkronberger";
      password_cmd = "${pkgs.coreutils}/bin/cat /run/secrets/spotify-password";
      device_name = "nixos";
      backend = "pulseaudio";
      bitrate = 320;
      device_type = "computer";
      # Disable Spotify Connect discovery — only ncspot is used locally
      disable_discovery = true;
    };
  };

  xdg.configFile."ncspot/config.toml".text = with config.scheme; ''
    backend = "pulseaudio"
    use_nerdfont = true

    [theme]
    background = "default"
    primary    = "#${base05}"
    secondary  = "#${base04}"
    title      = "#${base06}"
    playing    = "#${base0B}"
    playing_selected = "#${base0B}"
    playing_bg = "default"
    highlight  = "#${base06}"
    highlight_bg = "#${base02}"
    error      = "#${base08}"
    error_bg   = "default"
    statusbar  = "#${base04}"
    statusbar_progress = "#${base0F}"
    statusbar_bg = "#${base01}"
    cmdline    = "#${base05}"
    cmdline_bg = "default"
    search_match = "#${base0B}"

    [keybindings]
    "." = "next"
    "," = "previous"
    " " = "playpause"
    "s" = "search"
  '';
}
