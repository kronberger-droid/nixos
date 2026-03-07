{pkgs, ...}: {
  nixpkgs.overlays = [
    (_: prev: {
      brave = prev.brave.override {
        commandLineArgs = [
          "--password-store=gnome-keyring"
        ];
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
    busybox
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

    # Others
    fwupd
    nixpkgs-review
    xhost
    xauth
    woeusb
    clamav
    apptainer-overriden-nixos
  ];
}
