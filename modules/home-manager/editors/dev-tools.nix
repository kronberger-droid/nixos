{
  pkgs,
  inputs,
  ...
}: let
  rustToolchain = inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.stable.toolchain;
in {
  home.file.".rustfmt.toml".text = ''
    max_width = 70
  '';

  home.packages = with pkgs; [
    rustToolchain
    tokei
    cargo-generate
    serpl

    (python3.withPackages (ps:
      with ps; [
        pip
        numpy
        scipy
        h5py
        matplotlib
        touying
      ]))
  ];
}
