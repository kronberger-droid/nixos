{ pkgs, inputs, host, isNotebook, ... }:
let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.system}.dropkitten;
in
{
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook dropkittenPkg;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
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

        #custom Packages
        dropkittenPkg

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
        spotify
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
        zapzap

        # Video
        vlc

        # AI
        ollama
      ];

      xdg = {
        enable = true;
        mimeApps = {
          enable = true;
          defaultApplications = {
            "application/pdf" = "org.pwmt.zathura.desktop";  
            "x-scheme-handler/mailto" = "thunderbird.desktop";
          };
        };
      };
      
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
      };

      home.stateVersion = "24.11";
    };
  };
}
