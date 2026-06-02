{pkgs, ...}: {
  # rustfmt uses its default max_width (100); per-project rustfmt.toml still wins.
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
