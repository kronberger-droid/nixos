{pkgs, ...}: {
  # Allow running dynamically linked executables (non-Nix binaries)
  programs.nix-ld.enable = true;

  nixpkgs.overlays = [
    (_: prev: {
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
    parted

    # Basic cli tools
    eza
    bat
    bat-extras.core
    erdtree
    ripgrep
    rip2
    fd
    skim
    fzf
    xcp
    dust
    ouch
    tealdeer
    chafa

    # Network cli
    nmap
    wirelesstools
    # dig, host, nslookup. Handy for checking that a Cloudflare-proxied record
    # actually resolves — a proxied CNAME answers with Cloudflare's anycast A
    # records rather than the CNAME itself, which is easy to misread without it.
    dnsutils
    # Cloudflare Tunnel CLI. Only needed here for the administrative side:
    # `tunnel login` (writes ~/.cloudflared/cert.pem), `tunnel create`, and
    # `tunnel route dns`. The homeserver never gets this package from here —
    # it does not import modules/system — it gets the daemon via
    # services.cloudflared in modules/system/services/website.nix.
    cloudflared

    # Data cli
    usbutils
    exfat
    popsicle

    # Diagnostics
    lm_sensors

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
