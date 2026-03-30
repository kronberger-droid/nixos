{pkgs, ...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.devPi = {
      imports = [
        ./shell/nushell.nix
        ./shell/git.nix
      ];

      home = {
        username = "devPi";
        homeDirectory = "/home/devPi";
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}
