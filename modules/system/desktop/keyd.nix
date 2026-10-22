{pkgs, ...}: let
  # Everything but the alt/meta pair is the same on every keyboard.
  layers = main: {
    main =
      main
      // {
        rightshift = "layer(backspace_layer)";
        rightalt = "layer(meta_layer)";
        capslock = "overload(control, esc)";
      };
    "backspace_layer" = {
      space = "backspace";
    };
    "control:C" = {
      h = "left";
      k = "up";
      j = "down";
      l = "right";
    };
    "meta_layer" = {
      "o" = "macro(compose o \")";
      "u" = "macro(compose u \")";
      "a" = "macro(compose a \")";
      "s" = "macro(compose s s)";
    };
    "shift+meta_layer" = {
      "o" = "macro(compose O \")";
      "u" = "macro(compose U \")";
      "a" = "macro(compose A \")";
    };
  };
in {
  environment.systemPackages = with pkgs; [
    keyd
  ];

  services.keyd = {
    enable = true;
    keyboards = {
      # Apple config MUST come first to override wildcard
      apple = {
        ids = ["05ac:020c"];
        settings = layers {
          leftalt = "leftalt";
          leftmeta = "leftmeta";
        };
      };
      # Default config for non-Apple keyboards: alt and meta swapped, so the
      # key next to space is meta as on the Apple layout.
      default = {
        ids = ["*"];
        settings = layers {
          leftalt = "leftmeta";
          leftmeta = "leftalt";
        };
      };
    };
  };
}
