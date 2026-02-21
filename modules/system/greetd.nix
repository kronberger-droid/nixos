{
  pkgs,
  primaryCompositor,
  ...
}: {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
          --time \
          --asterisks \
          --user-menu \
          --cmd ${primaryCompositor} \
          --remember \
          --remember-user-session \
        '';
      };
    };
  };

  environment.etc."greetd/environments".text = ''
    sway
    niri
  '';
}
