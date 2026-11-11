{...}: {
  imports = [
    ./wireplumber-config.nix
  ];

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # No jack.enable: it is deprecated, because it puts PipeWire's libjack on
    # every process's LD_LIBRARY_PATH. Nothing here speaks JACK; if something
    # does later, run it under `pw-jack` from pipewire.jack instead.
    wireplumber.enable = true;
  };
}
