{ pkgs, ... }:

{
  services = {
    gnome.gnome-keyring.enable = true;
    gnome.gcr-ssh-agent.enable = false;
  };
  
  programs.ssh.startAgent = false;
  
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
}
