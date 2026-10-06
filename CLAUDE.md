# NixOS Configuration

## Searching Nixpkgs

Use `nh search <query>` to search for packages in nixpkgs. Prefer this over `nix search nixpkgs`.

## Checking a change

`nix flake check` is the gate before handing over for a switch: every host
evaluates (`eval-<host>`), alejandra formatting, `.nu` parsing, and deploy-rs.
For one host only: `nix build --no-link .#checks.x86_64-linux.eval-<host>`.
`nix fmt -- .` fixes formatting. `.githooks/pre-commit` runs the format and
parse checks on staged files.
