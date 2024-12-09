# /etc/nixos/flake.nix
{
  description = "flake for kronberger";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, home-manager,  ... }: {
    nixosConfigurations = {
      kronberger = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          ./modules/system/greetd.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.kronberger = { pkgs, ... }: {
              imports = [
                ./modules/sway.nix
                ./modules/kitty.nix
                ./modules/gtk.nix
                ./modules/helix.nix
                ./modules/shell.nix
                ./modules/git.nix
              ];
              home.username = "kronberger";
              home.homeDirectory = "/home/kronberger";
              programs.home-manager.enable = true;
              home.packages = with pkgs; [
                thunderbird
                brave
                bitwarden-desktop
                nautilus
                obsidian
                github-desktop
                libsecret
                yazi
                bluetuith
                spotify
                btop
                zed-editor
                zathura
                drawio
                feh
                inkscape
                megasync
                megacli
                neofetch
                fzf
                zotero-beta
                onlyoffice-desktopeditors
                nomachine-client
                teams-for-linux
                ltunify
                pandoc
                localsend
                okular
                xdg-user-dirs
                xdg-desktop-portal-wlr
                xdg-desktop-portal
                speedcrunch
                element-desktop
                caligula
                gthumb
                serpl
                taskwarrior
              ];

              home.file.".config/swappy/config".text = ''
                [Default]
                save_dir=$HOME/Pictures/Screenshots
                save_filename_format=swappy-%Y-%m-%d-%H-%M-%S.png
                show_panel=true
                line_size=10
                text_size=15
                text_font=monospace
                paint_mode=rectangle
                early_exit=true
                fill_shape=true
              '';

              programs.yazi = {
                enable = true;
                settings = { manager = { show_hidden = true; }; };
              };

              programs.vscode = {
                enable = true;
                package = pkgs.vscodium;
              };

              home.stateVersion = "24.11";
            };
          }
        ];
      };
    };
  };
}
