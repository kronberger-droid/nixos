{...}: {
  # Rust replacement for update-users-groups.pl. Same semantics, mutableUsers
  # included.
  #
  # Knock-on: agenix keys its install mechanism off this option, so secrets
  # come from agenix-install-secrets.service rather than an activation script.
  # That unit orders itself `after = ["systemd-sysusers.service"]`, which does
  # not exist under userborn, so it is not actually ordered against
  # userborn.service. If secrets ever come up owned by a numeric gid, that
  # race is the cause.
  services.userborn.enable = true;

  # Do not add system.etc.overlay.enable. Tried 2026-08-14: a live `switch`
  # replaces /etc with an erofs lowerdir plus an empty upper, hiding every
  # non-store file. The ssh host keys go with it, so agenix decrypts nothing
  # and every secret on the box is gone until reboot. Would need `boot` plus a
  # reboot to adopt, and it is still experimental upstream.
}
