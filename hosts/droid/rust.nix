{pkgs, ...}: let
  # rust-overlay toolchain (replaces fenix). `default` already bundles cargo,
  # rustc, clippy, rustfmt; add rust-analyzer + rust-src for editor support.
  rustToolchain = pkgs.rust-bin.stable.latest.default.override {
    extensions = ["rust-analyzer" "rust-src"];
  };
in {
  environment.packages = with pkgs; [
    # Core Rust toolchain (rustc, cargo, rustfmt, clippy, rust-analyzer, …)
    rustToolchain

    # Build and linking tools. clang is the linker driver Rust shells out to;
    # mold is the actual linker selected via RUSTFLAGS below. lld is dropped —
    # it already ships inside clang's LLVM and nothing references it. The heavier
    # cargo-* dev/profiling tools (expand, watch, edit, outdated, audit, bloat,
    # flamegraph, nextest, llvm-cov) are desktop-only; install ad hoc with
    # `nix shell nixpkgs#cargo-…` if ever needed on the phone.
    clang # C/C++ compiler (required for Rust linking)
    mold # Fast linker
  ];

  # Set environment variables for Rust
  environment.sessionVariables = {
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
    # Use mold as the default linker for faster builds
    RUSTFLAGS = "-C link-arg=-fuse-ld=mold";
  };
}
