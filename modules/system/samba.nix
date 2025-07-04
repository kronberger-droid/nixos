{
  services.samba = {
    enable = true;
    securityType = "user";
    openFirewall = true;
    
    settings = {
      global = {
        "invalid users" = [ "root" ];
        "passwd program" = "/run/wrappers/bin/passwd %u";
        security = "user";
        "map to guest" = "bad user";
        "guest account" = "nobody";
        "server string" = "NixOS Samba Server";
        "netbios name" = "nixos-host";
        workgroup = "WORKGROUP";
      };
      
      # Shared folder for QuickEMU
      quickemu-share = {
        path = "/home/your-username/quickemu-shared";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0664";
        "directory mask" = "0775";
        comment = "QuickEMU Windows Share";
        "force user" = "your-username";
        "force group" = "users";
      };
    };
  };
  
  # Ensure the shared directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d /home/your-username/quickemu-shared 0775 your-username users -"
  ];
  
  # Open necessary ports
  networking.firewall.allowedTCPPorts = [ 139 445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];
}
