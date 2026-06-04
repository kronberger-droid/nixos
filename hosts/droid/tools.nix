{pkgs, ...}: {
  # Droid-local, trimmed version of modules/home-manager/shell/tools.nix. The
  # shared module is desktop/server-flavoured (wiki-tui, lynx, translate-shell,
  # timr-tui, fastfetch); on the phone we keep only the small, daily-use CLI
  # tools. Add anything back with `nix shell nixpkgs#…` if needed ad hoc.
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
    rip2
    git-absorb
    file
  ];
}
