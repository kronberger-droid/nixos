{pkgs, ...}: {
  programs = {
    direnv = {
      enable = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
    btop = {
      enable = true;
      settings = {
        color_theme = "TTY";
      };
    };
    fastfetch = {
      enable = true;
      settings = {
        logo = {
          source = "nixos_small";
          padding = {
            top = 1;
            right = 3;
          };
        };
        display.separator = "  ";
        # No Packages module: counting the store costs ~230ms of the ~280ms
        # default run, which is most of what makes fastfetch feel sluggish here.
        modules = [
          {
            type = "title";
            format = "{user-name}@{host-name}";
          }
          "separator"
          {
            type = "os";
            key = "os";
            keyColor = "blue";
          }
          {
            type = "kernel";
            key = "kernel";
            keyColor = "blue";
            format = "{release}";
          }
          {
            type = "uptime";
            key = "up";
            keyColor = "blue";
          }
          {
            type = "shell";
            key = "shell";
            keyColor = "magenta";
          }
          {
            type = "terminal";
            key = "term";
            keyColor = "magenta";
          }
          {
            type = "wm";
            key = "wm";
            keyColor = "magenta";
          }
          {
            type = "cpu";
            key = "cpu";
            keyColor = "green";
            format = "{name}";
          }
          {
            type = "memory";
            key = "mem";
            keyColor = "green";
          }
          {
            type = "disk";
            key = "disk";
            keyColor = "green";
            folders = "/";
          }
          "break"
          {
            type = "colors";
            symbol = "circle";
          }
        ];
      };
    };
  };

  home.packages = with pkgs; [
    bat
    # batman/batgrep/batdiff resolve `bat` from PATH rather than a baked store
    # path, so they have to sit in the same layer as bat itself.
    bat-extras.core
    # Markdown reader: a real TUI (ratatui), vim keys, `/` or `f` to search.
    # Replaced glow, whose `-p` mode renders and then hands off to $PAGER, so
    # its scrolling and search were less's rather than its own.
    md-tui # `mdt file.md`
    rip2
    translate-shell
    wiki-tui
    lynx
    timr-tui
    git-absorb
    file
  ];
}
