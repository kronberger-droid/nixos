# What every host installs, next to what plain nixpkgs (the flake's own
# `nixpkgs` input, no overlays) has under the same name. Read by
# flake-versions.nu through `nix eval --impure --json`.
#
# A package is matched to nixpkgs by `pname`, since a derivation does not
# know the attribute it came from. That misses renamed attributes and
# wrappers; those come back with `attr = null` and count as custom.
{
  flake,
  # Host names, or null for every nixosConfiguration of this system.
  hosts ? null,
}: let
  inherit (flake.inputs.nixpkgs) lib;

  # Everything here is best effort: one package that throws on `.version`
  # or `.outPath` must not take the whole report down with it.
  try = x: let
    r = builtins.tryEval (builtins.deepSeq x x);
  in
    if r.success
    then r.value
    else null;

  info = plain: p: let
    pname = try (p.pname or (lib.getName p));
    version = try (p.version or (lib.getVersion p));
    base =
      if pname != null && try (plain ? ${pname}) == true && try (lib.isDerivation plain.${pname}) == true
      then plain.${pname}
      else null;
    baseVersion =
      if base == null
      then null
      else try (base.version or (lib.getVersion base));
    outPath = try p.outPath;
    baseOut =
      if base == null
      then null
      else try base.outPath;
  in {
    # Not `outPath`: toJSON would print the whole record as that one string.
    inherit pname version;
    out = outPath;
    name = try p.name;
    drvPath = try p.drvPath;
    attr =
      if base == null
      then null
      else pname;
    nixpkgsVersion = baseVersion;
    # Two different projects can share a pname (an own `drift` against the
    # nixpkgs one); differing homepages are how the caller tells.
    homepage = try (p.meta.homepage or null);
    nixpkgsHomepage =
      if base == null
      then null
      else try (base.meta.homepage or null);
    nixpkgsDrvPath =
      if base == null
      then null
      else try base.drvPath;
    # Different output, same input name: an overlay, a pin, or a dependency
    # of one. The caller tells those apart by the versions.
    overridden = base != null && outPath != null && baseOut != null && outPath != baseOut;
    # -1: nixpkgs is older than what the host gets, 0: same, 1: newer.
    cmp =
      if version == null || baseVersion == null
      then null
      else builtins.compareVersions baseVersion version;
  };

  host = name: let
    c = flake.nixosConfigurations.${name}.config;
    plain = flake.inputs.nixpkgs.legacyPackages.${c.nixpkgs.hostPlatform.system};
    users = c.home-manager.users or {};
    pkgs =
      c.environment.systemPackages
      ++ lib.concatMap (u: u.home.packages or []) (lib.attrValues users);
  in
    map (info plain) (lib.filter (p: try (lib.isDerivation p) == true) pkgs);

  names =
    if hosts == null
    then
      lib.attrNames (lib.filterAttrs
        (_: c: c.config.nixpkgs.hostPlatform.system == builtins.currentSystem)
        flake.nixosConfigurations)
    else hosts;
in
  lib.genAttrs names host
