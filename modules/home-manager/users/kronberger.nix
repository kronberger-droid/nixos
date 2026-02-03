{
  pkgs,
  inputs,
  host,
  isNotebook,
  ...
}: let
  dropkittenPkg = inputs.dropkitten.packages.${pkgs.stdenv.hostPlatform.system}.dropkitten;
  rustToolchain = inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.complete.toolchain;
in {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs host isNotebook dropkittenPkg;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-$(date +%Y%m%d-%H%M%S)";
    users.kronberger = {
      imports = [
        ../base16-scheme.nix
        ../terminal.nix
        ../taskwarrior.nix
        ../sway.nix
        ../kitty.nix
        ../rio.nix
        ../helix.nix
        ../nushell.nix
        ../git.nix
        ../zathura.nix
        ../yazi.nix
        ../theme.nix
        ../colors.nix
        ../bitwarden.nix
        ../aerc.nix
        ../quickemu.nix
        ../udiskie.nix
        ../firefox.nix
        ../nchat.nix
        ../qutebrowser.nix
      ];

      # Set default terminal emulator
      terminal.emulator = "kitty";

      programs = {
        direnv = {
          enable = true;
          enableNushellIntegration = true;
          nix-direnv.enable = true;
        };
        btop = {
          enable = true;
          settings = {
            color_theme = "TTY";
          };
        };
      };

      services = {
        spotifyd = {
          enable = true;
          settings = {
            global = {
              username = "martinkronberger";
              use_keyring = true;
              backend = "pulseaudio";
              device_name = "intelNuc";
              bitrate = 320;
              volume_normalisation = true;
              normalisation_pregain = -10;
              device_type = "computer";
            };
          };
        };
        gnome-keyring.enable = true;
      };

      home = {
        username = "kronberger";
        homeDirectory = "/home/kronberger";
        packages = with pkgs; [
          # Browsers
          brave

          # Custom Packages
          dropkittenPkg

          # messages
          thunderbird
          gurk-rs

          # Filemanagers
          nemo-with-extensions
          glib
          yazi
          zotero-beta
          serpl

          # Editors
          (pkgs.obsidian.overrideAttrs (oldAttrs: {
            postInstall =
              (oldAttrs.postInstall or "")
              + ''
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
          spotify

          # Information
          timr-tui
          fastfetch
          fzf
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
          pdfarranger
          zathura
          pdfpc
          inlyne

          # Remote
          localsend

          # System
          ltunify
          bluetuith

          # Wine
          wine
          winetricks

          # Math
          numbat

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
          claude-code-bin
          gemini-cli

          # Python
          (python3.withPackages (ps:
            with ps; [
              pip
              numpy
              scipy
              h5py
              matplotlib
              touying
            ]))
        ];

        file = {
          # Symlink claude to ~/.local/bin for native installation check
          ".local/bin/claude".source = "${pkgs.claude-code-bin}/bin/claude";

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

        stateVersion = "24.11";
      };

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
            "image/png" = "swayimg.desktop";
            "image/jpeg" = "swayimg.desktop";
            "image/gif" = "swayimg.desktop";
            "image/webp" = "swayimg.desktop";
            "image/svg+xml" = "swayimg.desktop";
            "image/tiff" = "swayimg.desktop";
          };
        };
        desktopEntries = {};
      };

      fonts.fontconfig.enable = true;
    };
  };
}
