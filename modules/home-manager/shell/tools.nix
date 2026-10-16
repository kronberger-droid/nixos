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
