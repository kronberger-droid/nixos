{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Replaces upstream's installPackages activation (nix-env --install) with
    # a build-free `nix-env --set` — proot on this device cannot allocate the
    # builder pty that the on-device user-environment build needs, which
    # aborted every switch before home-manager activation. See file header.
    ./user-environment.nix

    # Pins proot-static back to unstable-2023-11-11: the 2024-05-04 build
    # upstream ships breaks ALL local derivation builds on this device with
    # the same pseudoterminal error. See file header.
    ./proot-pin.nix

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
    SHELL = "${pkgs.bashInteractive}/bin/bash";
    # Disable channels warning since we're using flakes
    NIX_PATH = "";
  };

  # Login shell is bash, NOT nushell directly. nushell is not a POSIX login
  # shell: recent versions hard-abort with "Nushell launched as a REPL, but
  # STDIN is not a TTY" when nix-on-droid execs them at login, which bricks the
  # app on open. Bash logs in cleanly and hands off to nushell only once there's
  # a real interactive TTY (see programs.bash.initExtra in home.nix), so nu
  # inherits the terminal and starts fine. The interactive shell is still nu.
  # bashInteractive, not pkgs.bash: nixpkgs' plain bash is the minimal build
  # without readline — as a login shell it gives a degraded, editing-less
  # prompt. bashInteractive is the full build (and what nix-on-droid ships).
  user.shell = "${pkgs.bashInteractive}/bin/bash";

  # Read the changelog before changing this value
  system.stateVersion = "24.05";

  nix.extraOptions = ''
    experimental-features = nix-command flakes

    # Never build on-device: proot on this phone denies the pseudoterminal
    # Nix allocates for every local builder ("getting pseudoterminal
    # attributes: Permission denied"), so ALL builds are pushed to the
    # homeserver (aarch64 via binfmt emulation; kronberger is a trusted-user
    # there via modules/system/core/nix-settings.nix). max-jobs = 0 forces
    # remote building even though the builder's system matches ours.
    # Requires ~/.ssh/id_ed25519 (authorized on the homeserver) and its host
    # key in known_hosts. Both routes to the homeserver are listed — tailscale
    # (100.92.46.97, works from anywhere while the Tailscale app is connected)
    # first, home LAN (192.168.2.54) as fallback; nix skips an unreachable
    # builder and tries the next. Trade-off: switching needs the homeserver
    # reachable — acceptable, since local builds cannot work at all.
    builders = ssh://kronberger@100.92.46.97 aarch64-linux ; ssh://kronberger@192.168.2.54 aarch64-linux
    builders-use-substitutes = true
    max-jobs = 0
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
    extraSpecialArgs = {inherit inputs;};
  };
}
