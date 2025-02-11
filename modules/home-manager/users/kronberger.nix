{ lib, pkgs, inputs, host, ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  home-manager = {
    extraSpecialArgs = {
      inherit inputs host;
    };
    users.kronberger = {
      imports = [
        ../sway.nix
        ../kitty.nix
        ../helix.nix
        ../nushell.nix
        ../git.nix
        ../zathura.nix
      ];
      home.username = "kronberger";
      home.homeDirectory = "/home/kronberger";
      programs.home-manager.enable = true;
      home.packages = with pkgs; [
        thunderbird
        brave
        bitwarden-desktop
        nemo-with-extensions
        obsidian
        github-desktop
        libsecret
        yazi
        bluetuith
        spotify
        spotify-player
        btop
        zed-editor
        zathura
        drawio
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
        freecad-wayland
        lxqt.lxqt-policykit
        rpi-imager
        keyd
        ipe
        firefox
        gimp
        element-desktop
      ];
      
      services = {
        gnome-keyring.enable = true;
      };

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
      };

      home.stateVersion = "24.11";
    };
  };
}
