# Shared per-machine user SSH public keys, mirroring syncthing-devices.nix.
# Consumers do `builtins.attrValues (import .../ssh-keys.nix)` so every
# machine listed here can ssh into any host that imports this file.
# Purpose-specific keys (e.g. spectre's root nix-remote-builder key on the
# homeserver) stay hardcoded at their single use site, not here.
{
  spectre = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFXI1vd+dtthymv9vLy9QuoyGHuX5ZEkDXXSPfP6NVr spectre";
  # Rotated 2026-07-23; lives in ~/.ssh/id_ed25519 on intelNuc. The
  # superseded key was confirmed against the old id_ed25519.pub before
  # being replaced, which settles the earlier "unconfirmed" note.
  intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJT+vAet57bCbcEXqpegZfYehOEKgD4ZHvyulDEpZ3D8 intelNuc";
  P14E = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICus06RcZpJOWFagOHWhnHmahmaMrZg24vry8aJzjNZ+ kronberger@P14E";
  devpi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEy1NxD4g5ZjbOG40mE3GUAlWFxBEJ+dtFrjNW9C2WR kronberger@devpi";
  # Nothing Phone (Termux); key was generated on the homeserver, hence the comment
  phone = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGNMj1J9Y7Qc6oVzZQsAizZUJIP/F4bNn4hZmc4pCGeA kronberger@homeserver";
}
