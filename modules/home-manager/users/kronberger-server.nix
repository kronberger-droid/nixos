{
  pkgs,
  inputs,
  username,
  ...
}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${username} = {
      imports = [
        ../shell/nushell.nix
        ../shell/git.nix
        ../shell/tools.nix
        ../apps/zellij.nix
      ];

      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        stateVersion = "25.05";
      };

      programs.home-manager.enable = true;
    };
  };
}
