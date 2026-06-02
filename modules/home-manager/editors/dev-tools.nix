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
  # rustfmt uses its default max_width (100); per-project rustfmt.toml still wins.
  home.packages = with pkgs; [
    rustToolchain
    tokei
    cargo-generate
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
