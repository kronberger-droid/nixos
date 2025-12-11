{
  description = "Rust project with Nix packaging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix.url = "github:nix-community/fenix";
    naersk.url = "github:nix-community/naersk";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    fenix,
    naersk,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      toolchain = fenix.packages.${system}.stable.withComponents [
        "cargo"
        "clippy"
        "rust-src"
        "rustc"
        "rustfmt"
      ];

      naersk' = pkgs.callPackage naersk {
        cargo = toolchain;
        rustc = toolchain;
      };
    in {
      packages.default = naersk'.buildPackage {
        src = ./.;
      };

      devShells = {
        # Default: Use your system rustup for fast iteration
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustup
            pkg-config
          ];

          shellHook = ''
            echo "Rust development (rustup)"
            echo "Use 'nix develop .#nix' for pure Nix environment"
          '';
        };

        # Pure Nix environment for reproducible builds
        nix = pkgs.mkShell {
          nativeBuildInputs = [
            toolchain
            fenix.packages.${system}.rust-analyzer
            pkgs.pkg-config
          ];

          shellHook = ''
            echo "Pure Nix Rust environment"
            echo "Toolchain: $(rustc --version)"
          '';
        };
      };
    });
}
