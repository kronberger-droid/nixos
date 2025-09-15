{ pkgs, ... }:

{
  services = {
    gnome.gnome-keyring.enable = true;
    gnome.gcr-ssh-agent.enable = true;
  };
  
  programs.ssh.startAgent = false;
  
  security.pam.services = {
    swaylock.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
    login.enableGnomeKeyring = true;
    passwd.enableGnomeKeyring = true;
  };

  environment.systemPackages = with pkgs; [
    gnome-keyring
    seahorse
    gcr_4
    libsecret
  ];
}
