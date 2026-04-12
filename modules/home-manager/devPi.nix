{pkgs, inputs, ...}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
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
        packages = with pkgs; [
          yazi
          btop
          fastfetch
        ];
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}
