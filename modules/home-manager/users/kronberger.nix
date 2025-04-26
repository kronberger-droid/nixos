{ pkgs, inputs, host, isNotebook, ... }:
{
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
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
      home.packages = with pkgs; [
        # Browsers
        brave
        nyxt
        firefox

        # Mail
        thunderbird

        # Filemanagers
        nemo-with-extensions
        yazi
        megasync
        zotero-beta
        megacli
        serpl

        # Editors
        obsidian
        onlyoffice-desktopeditors

        # Music
        lmms
        spotify-player

        # Information
        btop
        fastfetch
        fzf
        serpl
        translate-shell

        # Images
        zathura
        drawio
        inkscape
        kdePackages.okular
        gthumb
        ipe
        gimp
        pdfarranger
        ffmpeg_6

        # Remote
        nomachine-client
        localsend

        # System
        ltunify
        rpi-imager
        bluetuith

        # xdg portal
        xdg-user-dirs
        xdg-desktop-portal-wlr
        xdg-desktop-portal
        xdg-desktop-portal-gtk

        # Math
        speedcrunch

        # CAD
        freecad-wayland

        # Safety
        lxqt.lxqt-policykit
        gcr
        seahorse
        libsecret
        bitwarden-desktop
        bitwarden-cli

        # Social
        element-desktop

        # Video
        vlc
      ];
      services.gnome-keyring = {
        enable = true;
      };

      home.file = {
        ".config/swappy/config".text = ''
          [Default]
          save_dir=$HOME/Pictures/Screenshots
          save_filename_format=swappy-%Y-%m-%d-%H-%M-%S.png
          show_panel=false
          line_size=5
          text_size=15
          text_font=monospace
          paint_mode=rectangle
          early_exit=true
          fill_shape=false
        '';
        ".local/share/applications/whatsapp-web.desktop".text = ''
          [Desktop Entry]
          Name=WhatsApp Web
          Exec=brave --app=https://web.whatsapp.com --password-store=gnome-keyring --enable-features=UseOzonePlatform --ozone-platform=wayland
          Icon=whatsapp
          Type=Application
          Categories=Network;
        '';
        ".local/share/applications/spotify.desktop".text = ''
          [Desktop Entry]
          Name=Spotify
          Exec=brave --app=https://open.spotify.com/ --password-store=gnome-keyring --enable-features=UseOzonePlatform --ozone-platform=wayland
          Icon=spotify
          Type=Application
          Categories=Network;
        '';
      };


      home.stateVersion = "24.11";
    };
  };
}
