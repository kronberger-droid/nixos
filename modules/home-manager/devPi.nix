{pkgs, inputs, ...}: {
  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.devPi = {
      imports = [
        # base16 module declares the `scheme` option, base16-scheme.nix fills
        # it in; git.nix reads it to colour gh-dash.
        inputs.base16.homeManagerModule
        ./theming/base16-scheme.nix

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
