# Overlay providing `pkgs.rust-glancer`: an experimental Rust LSP built for low
# memory use (target: under 100MB) and near-instant editor restarts, since it
# persists its index to disk rather than re-indexing on every start.
#
# It has to be built here because upstream publishes nothing else usable: it is
# not in nixpkgs, and the GitHub releases carry only VS Code `.vsix` bundles
# with the server binary buried inside. The workspace does expose a plain
# `rust-glancer` bin crate whose `lsp` subcommand serves over stdio, which is
# all a non-VS Code editor needs.
#
# Nothing references this attribute until `helix.rustLsp` is flipped to
# "rust-glancer" (it defaults to rust-analyzer), so no host pays the ~400-crate
# compile just for having the overlay applied.
#
# Bumping is `nix flake update rust-glancer-src`.
inputs: _final: prev: let
  src = inputs.rust-glancer-src;
in {
  rust-glancer = prev.rustPlatform.buildRustPackage {
    pname = "rust-glancer";
    # Every workspace crate pins version = "0.0.0", so the only version
    # upstream actually publishes is the one on the VS Code extension.
    version = (prev.lib.importJSON "${src}/editors/code/package.json").version;
    inherit src;

    cargoLock = {
      # Read at eval time, which is why the source is a `flake = false` input
      # rather than a fetchFromGitHub: an input is already a realised store
      # path, whereas a fetcher derivation would make this
      # import-from-derivation and force a download on every eval.
      lockFile = "${src}/Cargo.lock";
      # The five git dependencies are all the same pinned rev of rust-analyzer
      # (stdx, edition, test-utils), so builtins.fetchGit resolves them
      # straight out of the lockfile. Same trick the nushell overlay leans on,
      # and the reason there are no `outputHashes` to re-pin on every bump.
      allowBuiltinFetchGit = true;
    };

    # The workspace also holds vendored parser crates, a codegen tool and the
    # benchmark fixtures. Only the binary crate is wanted.
    cargoBuildFlags = ["--package" "rust-glancer"];

    # The suite leans on the `test_targets/` fixture crates and shells out to
    # rustc for sysroot discovery, neither of which survives the sandbox.
    # Upstream CI gates main already.
    doCheck = false;

    # Deliberately unwrapped. The server shells out to `cargo` for diagnostics
    # and reads `rustc --print sysroot` to find rust-src, and both should
    # resolve against whatever toolchain the project is using — pinning them to
    # this build's nixpkgs rustc would silently analyze against the wrong
    # standard library. The engine subprocess is found via std::env::current_exe,
    # so it needs nothing on PATH itself.
    meta = {
      description = "Rust LSP implementation optimized for low memory usage and fast editor restarts";
      homepage = "https://github.com/rust-glancer/rust-glancer";
      license = with prev.lib.licenses; [mit asl20];
      mainProgram = "rust-glancer";
      platforms = prev.lib.platforms.unix;
    };
  };
}
