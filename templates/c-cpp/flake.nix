{
  description = "C/C++ development shell with gcc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        # LSP and linting
        analysisTools = with pkgs; [
          clang-tools # clangd (LSP) + clang-tidy (linter)
          cppcheck    # static analysis
          bear        # generates compile_commands.json from Makefile builds
        ];

        # Build tools
        buildTools = with pkgs; [
          gcc
          gnumake
          cmake
          pkg-config
        ];

        # Debugging
        debugTools = with pkgs; [
          gdb
          valgrind
        ];
      in {
        devShells.default = pkgs.mkShell {
          name = "c-cpp dev shell";
          buildInputs = buildTools ++ analysisTools ++ debugTools;
          shellHook = ''
            echo "Using GCC: $(gcc --version | head -1)"
            echo "clangd available for LSP"
          '';
        };
      }
    );
}
