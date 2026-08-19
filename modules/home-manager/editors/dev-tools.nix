{pkgs, ...}: let
  # nixpkgs' default `rustc` trails upstream Rust stable (staging/mass-rebuild
  # lag), so we pull the toolchain from rust-overlay instead. `stable.latest`
  # tracks the newest released stable in the pinned rust-overlay rev, so it
  # advances on `nix flake update rust-overlay` with no edit here. `default`
  # bundles rustc/cargo/clippy/rustfmt; rust-analyzer + rust-src are added as
  # extensions for editor support. (Same pattern as hosts/droid/rust.nix.)
  rustToolchain = pkgs.rust-bin.stable.latest.default.override {
    extensions = ["rust-analyzer" "rust-src"];
  };
in {
  # Cargo's own defaults (profiles, aliases, linker) live in cargo.nix, which
  # hosts/droid/home.nix imports too — the phone has a toolchain but no
  # dev-tools.nix.
  imports = [./cargo.nix];

  # rustfmt uses its default max_width (100); per-project rustfmt.toml still wins.
  home.packages = with pkgs; [
    rustToolchain
    tokei
    cargo-generate
    # One process per test instead of one thread per test in a shared binary:
    # real parallelism, per-test timeouts, and a failing test can't poison the
    # rest of the run. `cargo test` stays available for doctests, which nextest
    # deliberately does not run.
    cargo-nextest
    # Checks Cargo.lock against the RustSec advisory DB. Pulls the DB over the
    # network into ~/.cargo/advisory-db on first run, so it only makes sense as
    # a thing you invoke by hand, not as part of a nix build.
    cargo-audit
    serpl

    (python3.withPackages (ps:
      with ps; [
        pip
        numpy
        scipy
        h5py
        matplotlib
        touying
      ]))
  ];
}
