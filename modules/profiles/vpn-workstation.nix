{
  config,
  lib,
  ...
}: {
  # On once the host's key is in ./secrets (security/agenix.nix); the
  # host's configuration.nix carries the addresses Mullvad gave that key.
  services.mullvad-wg = lib.mkIf (config.age.secrets ? mullvad-wg-key) {
    enable = true;
    privateKeyFile = config.age.secrets.mullvad-wg-key.path;
  };

  services.pia = {
    enable = true;
    environmentFile = config.age.secrets.pia-credentials.path;
  };

  services.tuwien-vpn = {
    enable = true;
    username = "mkronber@tuwien.ac.at";
    passwordFile = config.age.secrets.tuwien-vpn-password.path;
    totpSecretFile = config.age.secrets.tuwien-vpn-totp.path;
  };
}
