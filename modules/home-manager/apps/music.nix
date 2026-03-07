{pkgs, ...}: {
  home.packages = with pkgs; [
    spotify
  ];

  services.spotifyd = {
    enable = true;
    settings = {
      global = {
        username = "martinkronberger";
        use_keyring = true;
        backend = "pulseaudio";
        device_name = "intelNuc";
        bitrate = 320;
        volume_normalisation = true;
        normalisation_pregain = -10;
        device_type = "computer";
      };
    };
  };
}
