{
  services.samba = {
    enable = true;
    securityType = "user";
    openFirewall = true;
  };
  
  # Ensure the shared directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /home/your-username/quickemu-shared 0775 kronberger users -"
  ];
  
  # Open necessary ports
  networking.firewall.allowedTCPPorts = [ 139 445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
}
