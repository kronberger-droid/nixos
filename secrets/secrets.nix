let
  intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2nXGswPYhgVX6zwQAg3Wk8pfVw64pY+wIRIUoSyXYr root@intelNuc";
  spectre = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMo/agXzq/uXYxPRHuxy20rD/T09I/zQzLFjFmA5b5Ic root@spectre";
in {
  "pia-credentials.age".publicKeys = [intelNuc spectre];
  "tuwien-vpn-password.age".publicKeys = [intelNuc spectre];
  "openclaw-anthropic-api-key.age".publicKeys = [intelNuc spectre];
}
