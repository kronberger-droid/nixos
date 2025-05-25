{ config, lib, pkgs, ... }:{
  programs.yazi = {
    enable = true;
    settings = {
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
