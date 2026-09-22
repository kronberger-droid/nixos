{...}: {
  # Rust replacement for update-users-groups.pl. Same semantics, mutableUsers
  # included.
  #
  # Knock-on: agenix keys its install mechanism off this option, so secrets
  # come from agenix-install-secrets.service rather than an activation script.
  # That unit orders itself `after = ["systemd-sysusers.service"]`, an alias
  # of userborn.service, so secrets always arrive after users are made. Any
  # secret userborn itself reads must not come from agenix: see the password
  # unit in users.nix.
  services.userborn.enable = true;

  # Do not add system.etc.overlay.enable. Tried 2026-08-14: a live `switch`
  # replaces /etc with an erofs lowerdir plus an empty upper, hiding every
  # non-store file. The ssh host keys go with it, so agenix decrypts nothing
  # and every secret on the box is gone until reboot. Would need `boot` plus a
  # reboot to adopt, and it is still experimental upstream.
}
