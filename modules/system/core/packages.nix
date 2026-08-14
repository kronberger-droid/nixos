{
  lib,
  pkgs,
  ...
}: {
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
    # uutils in place of GNU coreutils for anything resolved through PATH.
    # Does not touch stdenv, so builds keep using GNU and nothing rebuilds.
    # hiPrio beats coreutils-full in the system-path buildEnv explicitly,
    # rather than leaning on nixpkgs' requiredPackages priority offset.
    # `-noprefix` is the drop-in; plain `uutils-coreutils` installs `uu-*`.
    (lib.hiPrio uutils-coreutils-noprefix)

    # Essentials
    helix
    git
    curl
    gparted
    parted

    # Basic cli tools
    eza
    erdtree
    ripgrep
    rip2
    fd
    skim
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
