{ lib, pkgs, inputs, host, ... }:
let
  isNotebook = host == "t480s";
in
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager = {
    extraSpecialArgs = {
      inherit inputs host;
    };
    users.kronberger = {
      imports = [
        ../../modules/sway.nix
        ../../modules/kitty.nix
        ../../modules/gtk.nix
        ../../modules/helix.nix
        ../../modules/shell.nix
        ../../modules/git.nix
      ];
      home.username = "kronberger";
      home.homeDirectory = "/home/kronberger";
      programs.home-manager.enable = true;
      home.packages = with pkgs; [
        thunderbird
        brave
        chromium
        bitwarden-desktop
        nemo-with-extensions
        obsidian
        github-desktop
        firefox
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
        ltunify
        localsend
        okular
        xdg-user-dirs
        xdg-desktop-portal-wlr
        xdg-desktop-portal
        xdg-desktop-portal-gtk
        speedcrunch
        caligula
        gthumb
        serpl
        translate-shell
      ];
      
      home.file = {
        ".config/swappy/config".text = ''
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
      } // lib.optionalAttrs isNotebook {
        ".config/way-displays/cfg.yaml".source = ../../configs/way-displays/cfg.yaml;
      };

      programs.yazi = {
        enable = true;
        settings = { manager = { show_hidden = true; }; };
      };
     
      home.stateVersion = "24.11";
    };
  };
}
