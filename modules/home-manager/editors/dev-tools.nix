{pkgs, ...}: {
  home.file.".rustfmt.toml".text = ''
    max_width = 70
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
