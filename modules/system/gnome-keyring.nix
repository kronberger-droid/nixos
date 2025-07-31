{ pkgs, ... }:

{
  services = {
    gnome = {
      gnome-keyring.enable = true;
      gcr-ssh-agent.enable = true;
    };
  };
  
  security.pam.services = {
    swaylock.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
  };

  environment.systemPackages = with pkgs; [
    gnome-keyring
    seahorse
    gcr_4
    libsecret
  ];

  # systemd.user.sockets.gcr-ssh-agent = {
  #   enable = true;
  #   wantedBy = [ "sockets.target" ];
  # };

  # systemd.user.services.gcr-ssh-agent = {
  #   enable = true;
  # };
}
