{pkgs, ...}: let
  # rust-overlay toolchain (replaces fenix). `default` already bundles cargo,
  # rustc, clippy, rustfmt; add rust-analyzer + rust-src for editor support.
  rustToolchain = pkgs.rust-bin.stable.latest.default.override {
    extensions = ["rust-analyzer" "rust-src"];
  };
in {
  environment.packages = [
    # Core Rust toolchain (rustc, cargo, rustfmt, clippy, rust-analyzer, …)
    rustToolchain

    # The heavier cargo-* dev/profiling tools (expand, watch, edit, outdated,
    # audit, bloat, flamegraph, nextest, llvm-cov) are desktop-only; install ad
    # hoc with `nix shell nixpkgs#cargo-…` if ever needed on the phone.
  ];

  # clang + mold used to live here alongside a RUSTFLAGS session variable that
  # selected mold. mold is still the right call on aarch64 (Rust 1.90 made
  # rust-lld the default only on x86_64-unknown-linux-gnu), but RUSTFLAGS was
  # the wrong lever: as an environment variable it *replaces* a project's
  # [build] rustflags rather than merging, and no checkout can override it.
  # Both the packages and the linker choice now come from the shared
  # modules/home-manager/editors/cargo.nix, which scopes them to the triple and
  # leaves a project's own .cargo/config.toml free to win.
  environment.sessionVariables = {
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
  };
}
