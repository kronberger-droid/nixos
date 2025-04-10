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
        brave
        thunderbird
        bitwarden-desktop
        bitwarden-cli
        nemo-with-extensions
        obsidian
        github-desktop
        libsecret
        yazi
        bluetuith
        spotify
        spotify-player
        btop
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
        kdePackages.okular
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
        ipe
        firefox
        gimp
        element-desktop
        vlc
        lmms
        seahorse
        gcr
        rustlings
        pdfarranger
        ffmpeg_6
        xdg-user-dirs
      ];

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
