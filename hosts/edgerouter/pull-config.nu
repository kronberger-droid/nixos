#!/usr/bin/env nu

# Refresh the EdgeRouter config snapshot that sits next to this script.
#
# Run it after any change committed on the router:
#
#     nu hosts/edgerouter/pull-config.nu
#
# This repo is public, so the redactions below are load-bearing. Check the diff
# before committing rather than trusting them blindly: EdgeOS grew a `wireguard
# private-key` node in 3.0, and any future secret gets a node name that these
# patterns do not know about yet.

def main [
  --host: string = "192.168.2.1"
  --user: string = "kronberger"
  # Defaults to the interactive key rather than the agent key, since this is
  # meant to be run by hand.
  --key: string = "~/.ssh/edgerouter/kronberger"
] {
  let dest = ([$env.FILE_PWD "config.boot"] | path join)

  let raw = (
    ssh -i ($key | path expand) -o IdentitiesOnly=yes
      $"($user)@($host)" "cat /config/config.boot"
  )

  if ($raw | str trim | is-empty) {
    error make {msg: $"got nothing back from ($host); is it reachable?"}
  }

  $raw
  | str replace --regex --all '(encrypted-password) .*' '$1 <redacted>'
  | str replace --regex --all '(plaintext-password) .*' '$1 <redacted>'
  | str replace --regex --all '(pre-shared-secret) .*' '$1 <redacted>'
  | str replace --regex --all '(private-key) .*' '$1 <redacted>'
  | str replace --regex --all '(\s+key) [A-Za-z0-9+/=]{20,}' '$1 <redacted>'
  | save --force $dest

  print $"wrote ($dest)"
  print "check `git diff` for anything secret the patterns missed"
}
