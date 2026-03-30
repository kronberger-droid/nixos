{pkgs, ...}: {
  # Allow running dynamically linked executables (non-Nix binaries)
  programs.nix-ld.enable = true;

  nixpkgs.overlays = [
    (_: prev: {
      # Use prebuilt electron to avoid broken chromium source build
      bitwarden-desktop = prev.bitwarden-desktop.override {
        electron_39 = prev.electron_39-bin;
      };

      brave = prev.brave.override {
        commandLineArgs = [
          "--password-store=gnome-keyring"
        ];
      };

      inpdf = prev.rustPlatform.buildRustPackage {
        pname = "inpdf";
        version = "0-unstable-2026-02-03";
        src = prev.fetchFromGitHub {
          owner = "jonhoo";
          repo = "inpdf";
          rev = "657fa9380b27563d5cf260c90ae3506de8516de8";
          hash = "sha256-CTvPXYOhCmkmXlLzG8gjLuvY7XgHzgKfjg3H66hrFH4=";
        };
        cargoHash = "sha256-q7DR0+u1p0Dkp6LhFvNHXuiZoC7am8XH+HC+suLgBY4=";
      };
    })
  ];

  environment.systemPackages = with pkgs; [
    # Essentials
    helix
    git
    curl
    gparted

    # Basic cli tools
    eza
    bat
    bat-extras.core
    less
    zoxide
    tree
    ripgrep
    rip2
    fd
    skim
    xcp
    dust
    ouch
    tealdeer

    # Network cli
    nmap
    wirelesstools

    # Data cli
    usbutils
    exfat
    popsicle

    # Secrets
    libsecret
    cryptsetup

    # Nix tooling
    nh
    nix-output-monitor
    cachix

    # Others
    fwupd
    nixpkgs-review
    xhost
    xauth
    woeusb
    apptainer-overriden-nixos
  ];
}
