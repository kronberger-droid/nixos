{pkgs, inputs, ...}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.mediaPi = {
      imports = [
        ./shell/nushell.nix
      ];

      home = {
        username = "mediaPi";
        homeDirectory = "/home/mediaPi";
        packages = with pkgs; [
          btop
          fastfetch
          fuzzel
        ];
        stateVersion = "25.05";
      };

      wayland.windowManager.sway = {
        enable = true;
        config = {
          terminal = "${pkgs.foot}/bin/foot";
          menu = "${pkgs.fuzzel}/bin/fuzzel";
          modifier = "Mod4";
          startup = [
            {command = "${pkgs.chromium}/bin/chromium";}
          ];
          bars = [{
            position = "top";
            statusCommand = "${pkgs.i3status}/bin/i3status";
            trayOutput = "*";
          }];
        };
      };

      programs.home-manager.enable = true;
    };
  };
}
