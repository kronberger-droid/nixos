{config, ...}: {
  services.pia = {
    enable = true;
    environmentFile = config.age.secrets.pia-credentials.path;
  };

  services.tuwien-vpn = {
    enable = true;
    passwordFile = config.age.secrets.tuwien-vpn-password.path;
  };
}
