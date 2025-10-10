{ pkgs, inputs, host, isNotebook, ... }:
let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.system}.dropkitten;
  rustToolchain = inputs.fenix.packages.${pkgs.system}.complete.toolchain;
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
        ../taskwarrior.nix
        ../sway.nix
        ../kitty.nix
        ../helix.nix
        ../nushell.nix
        ../git.nix
        ../zathura.nix
        ../yazi.nix
        ../theme.nix
        ../colors.nix
        ../bitwarden.nix
        ../himalaya.nix
        ../quickemu.nix
      ];

      programs = {
        direnv = {
          enable = true;
          enableNushellIntegration = true;
          nix-direnv.enable = true;
        };
      };

      services = {
        gnome-keyring.enable = true;
      };


      home.username = "kronberger";
      # home.homeDirectory = "/home/kronberger";
      home.packages = with pkgs; [
        # Browsers
        brave
        nyxt
        firefox

        # Custom Packages
        dropkittenPkg

        # Mail
        thunderbird

        # Filemanagers
        nemo-with-extensions
        glib
        yazi
        zotero-beta
        serpl

        # Editors
        (pkgs.obsidian.overrideAttrs (oldAttrs: {
          postInstall = (oldAttrs.postInstall or "") + ''
            substituteInPlace $out/share/applications/obsidian.desktop \
              --replace "Exec=obsidian" "Exec=obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland"
          '';
        }))
        onlyoffice-desktopeditors

        # Development
        rustToolchain
        tokei
        cargo-generate

        # Music
        # lmms
        spotify
        spotify-player
        ncspot

        # Information
        btop
        fastfetch
        fzf
        serpl
        translate-shell
        wiki-tui

        # Images
        drawio
        inkscape
        gthumb
        ipe
        gimp
        ffmpeg_6

        # PDF
        ghostscript
        mupdf
        pdfarranger
        kdePackages.okular
        zathura

        # Remote
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
        seahorse
        bitwarden-desktop
        rofi-rbw-wayland
        rbw
        openssl
        libsecret

        # Social
        element-desktop
        zapzap

        # Video
        vlc
        obs-studio

        # AI
        ollama
        claude-code
        gemini-cli

      ];

      xdg = {
        enable = true;
        mimeApps = {
          enable = true;
          defaultApplications = {
            "application/pdf" = "org.pwmt.zathura.desktop";  
            "x-scheme-handler/mailto" = "thunderbird.desktop";
            "x-scheme-handler/http" = "firefox.desktop";
            "x-scheme-handler/https" = "firefox.desktop";
            "text/html" = "firefox.desktop";
            "application/xhtml+xml" = "firefox.desktop";
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
