{
  description = "Rust development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          rustup
          pkg-config
        ];

        shellHook = ''
          echo "Rust development environment"
          echo "Using rustup: $(rustup --version 2>/dev/null || echo 'run: rustup default stable')"
        '';
      };
    });
  };
}
