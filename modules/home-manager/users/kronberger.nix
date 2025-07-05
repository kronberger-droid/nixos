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
        ../yazi.nix
        ../theme.nix
        ../colors.nix
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
        zotero-beta
        serpl

        # Editors
        obsidian
        onlyoffice-desktopeditors

        # Music
        # lmms
        spotify
        ncspot

        # Information
        btop
        fastfetch
        fzf
        serpl
        translate-shell
        wiki-tui

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

        # Math
        speedcrunch

        # CAD
        freecad-wayland

        # Safety
        lxqt.lxqt-policykit
        gcr
        seahorse
        bitwarden-desktop
        bitwarden-cli
        openssl

        # Social
        element-desktop
        zapzap
        iamb

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
            "image/png"       = "swayimg.desktop";
            "image/jpeg"      = "swayimg.desktop";
            "image/gif"       = "swayimg.desktop";
            "image/webp"      = "swayimg.desktop";
            "image/svg+xml"   = "swayimg.desktop";
            "image/tiff"      = "swayimg.desktop";
          };
        };
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

        ".local/share/fonts/Futura_PT".source = ../fonts/Futura_PT;

        ".local/share/fonts/gfsneohellenicmath".source = ../fonts/gfsneohellenicmath;
      };

      fonts.fontconfig.enable = true;

      home.stateVersion = "24.11";
    };
  };
}
