{
  description = "Rust GUI project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, fenix, ...}: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      toolchain = fenix.packages.${system}.stable.withComponents [
        "cargo" "clippy" "rust-src" "rustc" "rustfmt"
      ];
      guiDeps = with pkgs; [
        wayland wayland-protocols libxkbcommon
        xorg.libX11 xorg.libXcursor xorg.libXrandr xorg.libXi
        libGL libGLU gtk3 dbus dbus.lib zenity
      ];
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = [
          toolchain
          fenix.packages.${system}.rust-analyzer
          pkgs.pkg-config
          pkgs.gcc
          pkgs.cargo-expand
        ] ++ guiDeps;

        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath guiDeps;
      };
    });
  };
}
