# Shared per-machine user SSH public keys, mirroring syncthing-devices.nix.
# Consumers do `builtins.attrValues (import .../ssh-keys.nix)` so every
# machine listed here can ssh into any host that imports this file.
# Purpose-specific keys (e.g. spectre's root nix-remote-builder key on the
# homeserver) stay hardcoded at their single use site, not here.
{
  spectre = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr spectre";
  # TODO: unconfirmed — assumed to be intelNuc's key (was unlabeled in every
  # authorizedKeys list); verify against ~/.ssh/*.pub on intelNuc and label it.
  intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFijJelcEDGPlu9aDnjkLa4TWNXXJGeyHgw6ucANynAW";
  P14E = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICus06RcZpJOWFagOHWhnHmahmaMrZg24vry8aJzjNZ+ kronberger@P14E";
  devpi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEy1NxD4g5ZjbOG40mE3GUAlWFxBEJ+dtFrjNW9C2WR kronberger@devpi";
  # Nothing Phone (Termux); key was generated on the homeserver, hence the comment
  phone = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNMj1J9Y7Qc6oVzZQsAizZUJIP/F4bNn4hZmc4pCGeA kronberger@homeserver";
}
