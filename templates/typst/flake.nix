{
  description = "Environment with named dev environments and inherited shell specs.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs}: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells = {
      ${system} = {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.zathura
          ];
          shellHook = ''
            # Start zathura
            zathura main.pdf > zathura.log 2>&1 &
            ZATHURA_PID=$!

            # Start typst watch in a new rio window
            rio -e typst watch main.typ main.pdf &
            WATCH_PID=$!

            # Clean up on shell exit
            trap 'kill "$ZATHURA_PID" "$WATCH_PID"' EXIT

            hx main.typ
          '';
        };
      };
    };
  };
}
