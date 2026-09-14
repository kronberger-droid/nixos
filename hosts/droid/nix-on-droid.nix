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
    # coreutils comes from user-environment.nix, where uutils replaced GNU.
    # The `uu-`-prefixed build that sat here is redundant now.
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
    # homeserver (aarch64 via binfmt emulation) as the `nix-remote` account,
    # a trusted Nix user with no sudo (see hosts/homeserver). max-jobs = 0
    # forces remote building even though the builder's system matches ours.
    # Requires ~/.ssh/id_ed25519 (authorized for nix-remote on the homeserver)
    # and its host key in known_hosts. Both routes to the homeserver are
    # listed — tailscale (100.92.46.97, works from anywhere while the
    # Tailscale app is connected) first, home LAN (192.168.2.54) as fallback;
    # nix skips an unreachable builder and tries the next. Trade-off:
    # switching needs the homeserver reachable — acceptable, since local
    # builds cannot work at all.
    builders = ssh://nix-remote@100.92.46.97 aarch64-linux ; ssh://nix-remote@192.168.2.54 aarch64-linux
    builders-use-substitutes = true
    max-jobs = 0
  '';

  # Terminal colors from the shared base16 scheme, with the same slot policy
  # as theming/ansi.nix (which is a home-manager module and cannot be read
  # from here, so the mapping is restated; keep the two in step). This used
  # to be a hand-typed palette that had drifted from the scheme.
  terminal.colors = let
    s = (import ../../modules/home-manager/theming/base16-scheme.nix {}).scheme;
  in {
    background = "#${s.base00}";
    foreground = "#${s.base05}";
    cursor = "#${s.base05}";

    # Normal colors
    color0 = "#${s.base00}"; # black
    color1 = "#${s.base08}"; # red
    color2 = "#${s.base0B}"; # green
    color3 = "#${s.base0A}"; # yellow
    color4 = "#${s.base0D}"; # blue
    color5 = "#${s.base0E}"; # magenta
    color6 = "#${s.base0C}"; # cyan
    color7 = "#${s.base05}"; # white

    # Bright colors
    color8 = "#${s.base03}"; # bright black
    color9 = "#${s.base09}"; # bright red (orange in base16)
    color10 = "#${s.base0B}"; # bright green
    color11 = "#${s.base0A}"; # bright yellow
    color12 = "#${s.base0D}"; # bright blue
    color13 = "#${s.base0E}"; # bright magenta
    color14 = "#${s.base0C}"; # bright cyan
    color15 = "#${s.base07}"; # bright white
  };

  # Configure home-manager
  home-manager = {
    config = ./home.nix;
    backupFileExtension = "hm-bak";
    useGlobalPkgs = true;
    extraSpecialArgs = {inherit inputs;};
  };
}
