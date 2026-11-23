# NixOS Configuration

## Searching Nixpkgs

Use `nh search <query>` to search for packages in nixpkgs. Prefer this over `nix search nixpkgs`.

## Checking a change

Pick the check by how far the change reaches; the `nixos-config` skill has the
ladder. `nix flake check` is the full gate before a switch and mine to run:
every host evaluates (`eval-<host>`), alejandra formatting, `.nu` parsing,
deploy-rs, and the VM tests in `tests/`.
For one host only: `nix build --no-link .#checks.x86_64-linux.eval-<host>`.
`nix fmt -- .` fixes formatting. `.githooks/pre-commit` runs the format and
parse checks on staged files.
