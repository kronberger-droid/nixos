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
    rip2
    fastfetch
    translate-shell
    wiki-tui
    lynx
    timr-tui
    git-absorb
    file
  ];
}
