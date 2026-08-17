{
  description = "Rust project with Nix packaging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # The toolchain rides its own input so it is not welded to the nixpkgs pin:
    # `nix flake update rust-overlay` gets the newest stable without dragging
    # the whole package set forward. Same pattern as the fleet's
    # modules/home-manager/editors/dev-tools.nix.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    rust-overlay,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [rust-overlay.overlays.default];
      };
  in {
    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      # Deliberately nixpkgs' rustPlatform rather than one built on the overlay
      # toolchain: the package should build the same way here and anywhere that
      # never fetched rust-overlay. Toolchain currency is a dev-shell concern.
      default = pkgs.rustPlatform.buildRustPackage {
        pname = "my-package";
        version = "0.1.0";
        src = ./.;
        cargoLock.lockFile = ./Cargo.lock;
      };
    });

    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
      # `default` bundles rustc/cargo/clippy/rustfmt; rust-analyzer and rust-src
      # ride along as extensions, so no separate rust-analyzer package and no
      # RUST_SRC_PATH: it resolves std through the toolchain's own sysroot.
      toolchain = pkgs.rust-bin.stable.latest.default.override {
        extensions = ["rust-analyzer" "rust-src"];
      };
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = [
          toolchain
          pkgs.pkg-config
          pkgs.cargo-expand
        ];
      };
    });
  };
}
