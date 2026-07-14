{
  pkgs,
  inputs,
  ...
}: let
  # Stock nushell straight from nixpkgs, NOT the helix-mode fork
  # (modules/shared/nushell-overlay.nix). The fork builds from source (Rust) and
  # we deliberately keep the phone off any on-device compile, so use the prebuilt
  # cache binary. Pulling it from inputs.nixpkgs.legacyPackages (rather than
  # relying on "this host's pkgs happens to carry no nushell overlay") pins the
  # cached build explicitly — it stays stock even if the overlay is ever added to
  # this host's pkgs. nushell.nix detects the non-fork build via its version
  # string and falls back to vi edit-mode automatically. Used for both
  # home-manager's programs.nushell.package and the bash->nu handoff (home.nix).
  stockNushell = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nushell;
in {
  imports = [
    # Temporarily disabled: rust-overlay toolchain builds locally on-device and
    # is the prime suspect for the proot build-env pty/fd permission failure
    # during `nix-on-droid switch`. Re-enable once the switch succeeds without it.
    # ./rust.nix
  ];

  android-integration.termux-setup-storage.enable = true;

  # System-level packages. Shells, editor, git and CLI tools are managed by
  # home-manager (see ./home.nix), so only the bits that must exist outside
  # the HM profile live here.
  environment.packages = with pkgs; [
    bash
    uutils-coreutils
    openssh
    claude-code-bin
    yazi
    # Fonts + tools needed by the home-manager font activation script
    nerd-fonts.jetbrains-mono
    findutils
    gnused
  ];

  # Backup etc files instead of failing to activate if a file already exists
  environment.etcBackupExtension = ".bak";

  environment.sessionVariables = {
    SHELL = "${pkgs.bash}/bin/bash";
    # Disable channels warning since we're using flakes
    NIX_PATH = "";
  };

  # Login shell is bash, NOT nushell directly. nushell is not a POSIX login
  # shell: recent versions hard-abort with "Nushell launched as a REPL, but
  # STDIN is not a TTY" when nix-on-droid execs them at login, which bricks the
  # app on open. Bash logs in cleanly and hands off to nushell only once there's
  # a real interactive TTY (see programs.bash.initExtra in home.nix), so nu
  # inherits the terminal and starts fine. The interactive shell is still nu.
  user.shell = "${pkgs.bash}/bin/bash";

  # Read the changelog before changing this value
  system.stateVersion = "24.05";

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Terminal colors (based on the Kitty config)
  terminal.colors = {
    background = "#202020";
    foreground = "#d0d0d0";
    cursor = "#d0d0d0";

    # Normal colors
    color0 = "#151515"; # black
    color1 = "#ac4142"; # red
    color2 = "#7e8d50"; # green
    color3 = "#e5b566"; # yellow
    color4 = "#6c99ba"; # blue
    color5 = "#9e4e85"; # magenta
    color6 = "#7dd5cf"; # cyan
    color7 = "#d0d0d0"; # white

    # Bright colors
    color8 = "#505050"; # bright black
    color9 = "#ac4142"; # bright red
    color10 = "#7e8d50"; # bright green
    color11 = "#e5b566"; # bright yellow
    color12 = "#6c99ba"; # bright blue
    color13 = "#9e4e85"; # bright magenta
    color14 = "#7dd5cf"; # bright cyan
    color15 = "#f5f5f5"; # bright white
  };

  # Configure home-manager
  home-manager = {
    config = ./home.nix;
    backupFileExtension = "hm-bak";
    useGlobalPkgs = true;
    extraSpecialArgs = {inherit inputs stockNushell;};
  };
}
