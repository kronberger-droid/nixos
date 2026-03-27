#!/usr/bin/env nu

# Deploy NixOS configuration to homeserver

let target = "kronberger@192.168.2.54"
let flake = ".#nixosConfigurations.homeserver.config.system.build.toplevel"

print "Building configuration locally..."
nix build $flake

# Get the actual store path
let store_path = (readlink ./result | str trim)

print "Copying closure to server..."
nix copy --to $"ssh://($target)" $store_path

print "Activating on server..."
ssh -t $target sudo $"($store_path)/bin/switch-to-configuration" switch

print "Done."
