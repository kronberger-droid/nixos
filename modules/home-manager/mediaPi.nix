{pkgs, ...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.mediaPi = {
      imports = [
        ./shell/nushell.nix
        ./shell/git.nix
      ];

      home = {
        username = "mediaPi";
        homeDirectory = "/home/mediaPi";
        packages = with pkgs; [
          btop
          fastfetch
        ];

        # Deploy the kiosk start page
        file.".local/share/kiosk/start.html".source = ../../hosts/mediaPi/kiosk/start.html;

        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}
