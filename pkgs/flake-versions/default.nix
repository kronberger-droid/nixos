# `flake-versions`: the nu script plus the Nix expression it evaluates. nix,
# git and gh come from the caller's PATH, so it uses the same nix (and the
# same GitHub token, in the update job) as everything around it.
{
  runCommand,
  nushell,
}:
runCommand "flake-versions" {meta.mainProgram = "flake-versions";} ''
  mkdir -p $out/bin $out/share/flake-versions
  cp ${./collect.nix} $out/share/flake-versions/collect.nix
  substitute ${./flake-versions.nu} $out/bin/flake-versions \
    --replace-fail '@nu@' '${nushell}' \
    --replace-fail '@collect@' "$out/share/flake-versions/collect.nix"
  chmod +x $out/bin/flake-versions
''
