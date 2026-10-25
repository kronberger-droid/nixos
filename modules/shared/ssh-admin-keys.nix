# Per-machine admin keys, beside the everyday ones in ssh-keys.nix. Each is
# passphrase-protected in ~/.ssh/id_ed25519_admin and never loaded into the
# agent: oo7-ssh-agent signs for any process of the user and cannot require
# a confirmation, so a key it serves is a key every local process can use.
#
# They exist for the homeserver's root-capable accounts: ${username} there has
# NOPASSWD sudo for deploy-rs, and nix-remote is a trusted Nix user. A machine
# listed here gets its ssh_config for `homeserver` pointed at this key
# (users/kronberger.nix). Generate one with
#   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_admin -C kronberger@<host>-admin
{
  intelNuc = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkV0U5ZRxVw7jES8CD6SPI7o/N2wf6azR7b3ZdTCSm2 kronberger@intelNuc-admin";
}
