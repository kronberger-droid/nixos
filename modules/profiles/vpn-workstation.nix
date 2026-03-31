{config, ...}: {
  services.pia = {
    enable = true;
    environmentFile = config.age.secrets.pia-credentials.path;
  };

  services.tuwien-vpn = {
    enable = true;
    username = "e12202316@student.tuwien.ac.at";
    passwordFile = config.age.secrets.tuwien-vpn-password.path;
    totpSecretFile = config.age.secrets.tuwien-vpn-totp.path;
  };
}
