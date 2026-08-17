# Fleet-wide cargo defaults. Cargo reads $CARGO_HOME/config.toml (~/.cargo by
# default) on every invocation, whatever directory it runs from, so this is the
# one place to set build defaults that should hold everywhere.
#
# Imported by editors/dev-tools.nix (desktops/server) and by hosts/droid/home.nix,
# which is why it is a leaf module rather than part of dev-tools.nix: the phone
# gets the toolchain from hosts/droid/rust.nix, not from dev-tools.nix.
#
# Precedence gotcha, worth knowing before adding anything here: profile keys in
# this file take priority over a project's own Cargo.toml [profile.*], not the
# other way round. A crate that deliberately asks for full debuginfo in dev will
# silently not get it. Keep this to settings safe to impose on every checkout.
{
  lib,
  pkgs,
  ...
}: let
  # Rust 1.90 made rust-lld the default linker on x86_64-unknown-linux-gnu, so
  # there is nothing left for mold to win there — confirmed on 1.97, where the
  # link line already runs through rustlib/…/gcc-ld/ld.lld. aarch64 was not part
  # of that change and still links through gcc's GNU ld, so mold stays worth its
  # weight on the phone. Scope the override to the platforms that benefit.
  useMold = !pkgs.stdenv.hostPlatform.isx86_64;
  rustTarget = pkgs.stdenv.hostPlatform.rust.rustcTarget;
in {
  # clang is the linker driver rustc shells out to below; mold is the linker it
  # then selects. Both only make sense where useMold is on.
  home.packages = lib.optionals useMold [pkgs.clang pkgs.mold];

  home.file.".cargo/config.toml".text =
    ''
      # Full debuginfo is the dev default and usually dominates both link time
      # and target/ size. line-tables-only keeps backtraces with file:line
      # (enough for panics, profilers and flamegraphs) and drops the variable
      # info you only need when actually stepping in a debugger.
      [profile.dev]
      debug = "line-tables-only"
      split-debuginfo = "unpacked"

      # Dependencies get compiled once and then executed over and over, so
      # buying faster execution with a little of their build time is close to
      # free. debug = 0 because you don't step into them anyway; cargo spells
      # that as `-C strip=debuginfo` so the rmeta fingerprint stays stable.
      [profile.dev.package."*"]
      debug = 0
      opt-level = 1

      # `test` inherits `dev`, so both blocks above apply to test builds too.
      # That pays off more there than in `dev`: cargo links a separate binary
      # per test target, so cheaper linking compounds across a workspace, and
      # opt-level = 1 on deps shows up directly in test runtime.

      [alias]
      t = "nextest run"
    ''
    + lib.optionalString useMold ''

      # Scoped to the triple rather than exported as a RUSTFLAGS environment
      # variable: RUSTFLAGS *replaces* a project's [build] rustflags instead of
      # merging with it, and nothing in a checkout can override an env var. As
      # a config key this is the lowest-priority config file in cargo's
      # hierarchy, so a project's own .cargo/config.toml still wins.
      [target.${rustTarget}]
      linker = "clang"
      rustflags = ["-C", "link-arg=-fuse-ld=mold"]
    '';
}
