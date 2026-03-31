{
  description = "Rust development shell with GUI support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [rust-overlay.overlays.default];
        };

        rustTools = {
          stable = pkgs.rust-bin.stable.latest.default.override {
            extensions = ["rust-src"];
          };
          analyzer = pkgs.rust-bin.stable.latest.rust-analyzer;
        };

        devTools = with pkgs; [
          cargo-expand
          cargo-dist
          pkg-config
          gcc
        ];

        guiDeps = with pkgs; [
          # Wayland
          wayland
          wayland-protocols
          libxkbcommon

          # X11 fallback
          xorg.libX11
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXi

          # OpenGL
          libGL
          libGLU

          # GTK for file dialogs (rfd)
          gtk3

          # D-Bus for portal file dialogs
          dbus
          dbus.lib

          # Zenity fallback for file dialogs
          zenity
        ];

        rustDeps =
          [
            rustTools.stable
            rustTools.analyzer
          ]
          ++ devTools;

        shellHook = ''
          echo "Using Rust toolchain: $(rustc --version)"
          export CARGO_HOME="$HOME/.cargo"
          export RUSTUP_HOME="$HOME/.rustup"
          mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath guiDeps}:$LD_LIBRARY_PATH"
        '';
      in {
        devShells.default = pkgs.mkShell {
          name = "rust-gui-dev";
          buildInputs = rustDeps ++ guiDeps;
          inherit shellHook;
        };
      }
    );
}
