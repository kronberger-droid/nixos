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

    # Common Rust development tools
    cargo-expand # Expand macros
    cargo-watch # Auto-rebuild on file changes
    cargo-edit # cargo add, cargo rm, cargo upgrade commands
    cargo-outdated # Check for outdated dependencies
    cargo-audit # Security vulnerability scanner
    cargo-bloat # Find out what takes most space in your binary
    cargo-flamegraph # Generate flamegraphs for profiling
    cargo-nextest # Next-generation test runner
    cargo-llvm-cov # Code coverage with LLVM

    # Build and linking tools
    clang # C/C++ compiler (required for Rust linking)
    mold # Fast linker
    lld # LLVM linker (alternative)
  ];

  # Set environment variables for Rust
  environment.sessionVariables = {
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
    # Use mold as the default linker for faster builds
    RUSTFLAGS = "-C link-arg=-fuse-ld=mold";
  };
}
