# Secrets Management with agenix

This directory contains age-encrypted secrets managed by [agenix](https://github.com/ryantm/agenix).

## Overview

Secrets are encrypted with age and can only be decrypted by authorized hosts. Each host has an SSH key, and secrets are encrypted to allow specific hosts to decrypt them.

## Current Configuration

### Authorized Hosts

- **intelNuc**: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2nXGswPYhgVX6zwQAg3Wk8pfVw64pY+wIRIUoSyXYr`
- **spectre**: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMo/agXzq/uXYxPRHuxy20rD/T09I/zQzLFjFmA5b5Ic`

### Secrets

- **pia-credentials.age**: PIA VPN credentials (accessible by intelNuc and spectre)

## Common Operations

### Editing a Secret

```bash
# Edit an existing secret
agenix -e secrets/pia-credentials.age
```

The secret will be decrypted, opened in your `$EDITOR`, then re-encrypted when you save and close the editor.

### Creating a New Secret

1. Add the secret definition to `secrets.nix`:

```nix
{
  "new-secret.age".publicKeys = [ intelNuc spectre ];
}
```

2. Create and edit the secret:

```bash
agenix -e secrets/new-secret.age
```

3. Reference the secret in your NixOS configuration (e.g., in `modules/system/agenix.nix`):

```nix
age.secrets.new-secret = {
  file = "${inputs.self}/secrets/new-secret.age";
  path = "/run/secrets/new-secret";
  mode = "0400";
  owner = "root";
};
```

### Adding a New Host

1. Get the host's SSH public key:

```bash
# On the new host, get the root SSH key
sudo ssh-keyscan localhost | grep ssh-ed25519
# OR from the host's /etc/ssh directory
cat /etc/ssh/ssh_host_ed25519_key.pub
```

2. Add the host key to `secrets.nix`:

```nix
let
  newHost = "ssh-ed25519 AAAA...";
in
{
  "pia-credentials.age".publicKeys = [ intelNuc spectre newHost ];
}
```

3. Re-key all secrets to include the new host:

```bash
agenix -r
```

This will re-encrypt all secrets with the updated list of authorized keys.

## Security Notes

- **Never commit unencrypted secrets** to the repository
- Host SSH keys are public keys and safe to commit
- Secrets are decrypted at boot time and placed in `/run/secrets/`
- The `/run/secrets/` directory is in-memory (tmpfs) and cleared on reboot
- Only root can access secrets by default unless you specify a different owner/mode

## Troubleshooting

### "Permission denied" when editing a secret

Make sure you have the private key for one of the authorized hosts available in your SSH agent or at the default SSH key location.

### Secret not decrypting on a host

1. Verify the host's SSH key is in `secrets.nix`
2. Ensure you've run `agenix -r` to re-key secrets after adding the host
3. Check that the secret file exists and has been committed to git

## References

- [agenix GitHub Repository](https://github.com/ryantm/agenix)
- [age Encryption Tool](https://github.com/FiloSottile/age)
