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
    # Rust in place of btop. Its default palette is the terminal's ANSI
    # colours, which is what btop's "TTY" theme was set for.
    bottom.enable = true;
  };

  home.packages = with pkgs; [
    flake-versions # `flake-versions tui`: pins, uncached builds, stale inputs
    bat
    # batman/batgrep/batdiff resolve `bat` from PATH rather than a baked store
    # path, so they have to sit in the same layer as bat itself.
    bat-extras.core
    translate-shell
    lynx
    file
  ];
}
