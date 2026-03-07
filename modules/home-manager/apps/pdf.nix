{pkgs, ...}: {
  home.packages = with pkgs; [
    ghostscript
    pdfarranger
    pdfpc
    inlyne
    zathura
  ];
}
