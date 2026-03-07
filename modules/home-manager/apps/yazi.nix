{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    flavors = {
      "base16-transparent" = ./yazi/base16-transparent.toml;
    };
    settings = {
      flavor = "base16-transparent";
      opener = {
        "detached-pdf" = [
          {
            run = ''setsid ${pkgs.zathura}/bin/zathura "$@"'';
            orphan = true;
          }
        ];
        "detached-image" = [
          {
            run = ''setsid ${pkgs.swayimg}/bin/swayimg "$@"'';
            orphan = true;
          }
        ];
      };

      open = {
        prepend_rules = [
          # send pdfs to detached zathura
          {
            name = "*.pdf";
            use = "detached-pdf";
          }
          # send images to detaced swayimg
          {
            name = "*.png";
            use = "detached-image";
          }
          {
            name = "*.jpg";
            use = "detached-image";
          }
          {
            name = "*.jpeg";
            use = "detached-image";
          }
          {
            name = "*.gif";
            use = "detached-image";
          }
          {
            name = "*.svg";
            use = "detached-image";
          }
        ];
      };
    };
  };
}
