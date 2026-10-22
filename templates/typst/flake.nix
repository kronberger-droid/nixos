{
  description = "Typst document dev shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # Tools only. The editor/viewer/watch layout comes from `dev`, which runs
    # each pane through `nix develop -c`, so a shellHook here would fire once
    # per pane.
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        pkgs.typst
        pkgs.zathura
      ];
    };
  };
}
