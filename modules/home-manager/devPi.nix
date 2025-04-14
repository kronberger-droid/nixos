{ lib, pkgs, inputs, ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";
  home-manager = {
    users.devPi = {
      imports = [
        ./nushell.nix
        ./git.nix
        ./helix.nix
      ];
      home.username = "devPi";
      home.homeDirectory = "/home/devPi";
      programs.home-manager.enable = true;
      home.packages = with pkgs; [
        yazi
        btop
        neofetch
        fzf
      ];
  
      home.stateVersion = "25.05";
    };
  };
}
