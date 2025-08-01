{ pkgs, inputs, ... }:
{
  environment.systemPackages = with pkgs; [
    keyd
  ];

  services.keyd = {
    enable = true;
    keyboards = {
      # Apple config MUST come first to override wildcard
      apple = {
        ids = [ "05ac:020c" ];
        settings = {
          main = {
            leftalt = "leftalt";
            leftmeta = "leftmeta";
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
      };
      # Default config for non-Apple keyboards
      default = {
        ids = [ "*"];
        settings = {
          main = {
            leftalt = "leftmeta";
            leftmeta = "leftalt";
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
      };
    };
  };
}
