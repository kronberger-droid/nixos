{pkgs, ...}: {
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

  home.packages = with pkgs; [
    fastfetch
    fzf
    translate-shell
    wiki-tui
    lynx
    timr-tui
    git-absorb
    ouch
  ];
}
