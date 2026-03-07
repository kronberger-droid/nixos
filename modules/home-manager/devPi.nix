{pkgs, ...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.devPi = {
      imports = [
        ./shell/nushell.nix
        ./shell/git.nix
        ./editors/helix.nix
      ];

      home = {
        username = "devPi";
        homeDirectory = "/home/devPi";
        packages = with pkgs; [
          yazi
          btop
          fastfetch
          fzf
        ];
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}
