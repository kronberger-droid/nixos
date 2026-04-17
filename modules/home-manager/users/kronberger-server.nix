{pkgs, inputs, ...}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.kronberger = {
      imports = [
        ../shell/nushell.nix
        ../shell/git.nix
        ../shell/tools.nix
      ];

      home = {
        username = "kronberger";
        homeDirectory = "/home/kronberger";
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}
