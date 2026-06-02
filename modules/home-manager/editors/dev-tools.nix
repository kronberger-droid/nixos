{
  pkgs,
  isNotebook,
  ...
}: {
  # Wider lines on the desktop; narrower on notebooks where screens are smaller.
  home.file.".rustfmt.toml".text = ''
    max_width = ${toString (if isNotebook then 70 else 100)}
  '';

  home.packages = with pkgs; [
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
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
