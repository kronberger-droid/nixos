{
  config,
  lib,
  pkgs,
  inputs,
  osConfig ? null,
  ...
}: {
  # rbw only reads an existing device_id and writes one when it is missing,
  # so a read-only link to the agenix copy is safe. Set only on hosts that
  # have their secrets/rbw-device-id-<host>.age.
  home.file.".local/share/rbw/device_id" = lib.mkIf ((osConfig.age.secrets or {}) ? rbw-device-id) {
    source = config.lib.file.mkOutOfStoreSymlink osConfig.age.secrets.rbw-device-id.path;
  };

  home.packages = with pkgs; [
    bitwarden-desktop
  ];
  programs.rbw = {
    enable = true;
    settings = {
      email = "kronberger@proton.me";
      base_url = "https://vault.bitwarden.eu";
      # The unlock prompt as a sieb panel, themed by sieb/pinentry.toml
      # from desktop/sieb.nix. Any layer-shell compositor will do, so sway
      # hosts get it too.
      pinentry = inputs.sieb.packages.${pkgs.stdenv.hostPlatform.system}.pinentry;
    };
  };
}
