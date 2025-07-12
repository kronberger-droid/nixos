{ config, pkgs, lib, ... }:

{
  # Enable GNOME Keyring for secrets and passwords
  services.gnome.gnome-keyring.enable = true;
  
  # Enable PAM integration for automatic unlock on login
  security.pam.services = {
    login.enableGnomeKeyring = true;
    swaylock.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
  };

  # Install required packages
  environment.systemPackages = with pkgs; [
    gnome-keyring
    seahorse          # GUI for managing keyring
    gcr_4                   # Modern SSH agent (gcr-ssh-agent)
    libsecret               # For secret-tool CLI
  ];

  # Enable gcr-ssh-agent socket (SSH_AUTH_SOCK will be set automatically)
  systemd.user.sockets.gcr-ssh-agent = {
    enable = true;
    wantedBy = [ "sockets.target" ];
  };

  # The service will be started automatically by the socket
  systemd.user.services.gcr-ssh-agent = {
    enable = true;
  };
}
