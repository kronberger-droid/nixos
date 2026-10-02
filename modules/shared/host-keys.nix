# Root SSH host keys (/etc/ssh/ssh_host_ed25519_key.pub) of each NixOS host.
# Two jobs: agenix recipients (secrets/secrets.nix), and builder identities,
# since nix-daemon on a workstation reaches the homeserver's `nix-remote`
# account with its own host key (core/nix-settings.nix). A reinstall that
# regenerates a host key means updating it here, re-keying the secrets, and
# redeploying the homeserver so builds from that host offload again.
{
  intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2nXGswPYhgVX6zwQAg3Wk8pfVw64pY+wIRIUoSyXYr root@intelNuc";
  spectre = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMo/agXzq/uXYxPRHuxy20rD/T09I/zQzLFjFmA5b5Ic root@spectre";
  homeserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGfoblAvhTOErUvBVJXFrlzUwwQeQxcsu0864ffnllpW root@homeserver";
  # Comment is from install time, before the hostname was set.
  P14E = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEk1t3/oxPz8Rz5UDZPyYZn0GjUkleGMfKDytYdrtzUY root@nixos";
}
