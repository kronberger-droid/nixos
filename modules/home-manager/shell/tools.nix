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
    flake-versions # `flake-versions tui`: pins, uncached builds, stale inputs
    bat
    # batman/batgrep/batdiff resolve `bat` from PATH rather than a baked store
    # path, so they have to sit in the same layer as bat itself.
    bat-extras.core
    translate-shell
    wiki-tui
    lynx
    file
  ];
}
