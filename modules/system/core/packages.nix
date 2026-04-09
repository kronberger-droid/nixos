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
          "--password-store=basic"
        ];
      };

      # TODO: remove once nixpkgs has >= 2.1.92 (NixOS/nixpkgs#506537)
      claude-code-bin = prev.claude-code-bin.overrideAttrs (old: rec {
        version = "2.1.92";
        src = prev.fetchurl {
          url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/linux-x64/claude";
          sha256 = "e22324514967ff2d5e9f91f0ee37e4675bf8b6dfec27fafb19cb25cc5b23fcaf";
        };
      });

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
    zoxide
    erdtree
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
    cryptsetup

    # Nix tooling
    nh
    nix-output-monitor
    cachix

    # Git tooling
    gita

    # Others
    fwupd
    nixpkgs-review
    xhost
    xauth
    woeusb
    apptainer-overriden-nixos
  ];
}
