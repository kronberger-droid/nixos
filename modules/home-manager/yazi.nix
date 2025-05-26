{ config, lib, pkgs, ... }:{
  programs.yazi = {
    enable = true;
    flavors = {
      "base16-transparent" = ./yazi/base16-transparent.toml;
    };
    settings = {
      flavor = "base16-transparent";
      opener = {
        "detached-pdf" = [
          {
            run    = ''setsid zathura "$@"'';
            orphan = true;
          }
        ];
      };

      open = {
        prepend_rules = [
          {
            name = "*.pdf";
            use  = "detached-pdf";
          }
        ];
      };
    };
  };
}
