# Tooling that agent runtimes need to sandbox themselves. claude-science
# refuses to start without bwrap on PATH, and its sandbox networking (like
# Claude Code's Bash sandbox on Linux) bridges through socat. Workstations get
# this through security/default.nix; the homeserver imports it directly.
#
# nixpkgs' bwrap is not setuid, so it relies on unprivileged user namespaces.
# NixOS leaves those on, and hardening.nix does not touch them. Keep it that
# way, or this package installs fine and then fails at runtime.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    bubblewrap
    socat
  ];
}
