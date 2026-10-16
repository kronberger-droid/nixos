# The complete tool set of an unattended Claude Code agent, as one list.
#
# The flake-autoupdate agent runs with exactly this on PATH and nothing else
# (services/flake-autoupdate.nix), and the flake exports the same list as
# `devShells.<system>.agent`, so
#
#   nix develop .#agent --ignore-environment
#
# reproduces the agent's environment for debugging a prompt by hand. Adding a
# tool here widens what every unattended agent can run, so it belongs in the
# same review as a change to their --allowedTools.
#
# `claude-code-bin` comes from the claude-code input through commonOverlays
# in flake.nix; `nix` follows lixModule there.
pkgs:
with pkgs; [
  claude-code-bin
  lix
  git
  jq
  coreutils
  findutils
  gnugrep
  gnused
  gnutar
  diffutils
]
