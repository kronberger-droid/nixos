{ pkgs, ... }:{
  programs.git = {
    enable = true;
    userName = "Martin Kronberger";
    userEmail = "e12202316@student.tuwien.ac.at";

    lfs.enable = true;  # Enables Git LFS
    extraConfig = {
      filter.lfs.required = true;
      filter.lfs.clean = "git-lfs clean -- %f";
      filter.lfs.smudge = "git-lfs smudge -- %f";
      filter.lfs.process = "git-lfs filter-process";
    };
  };

  # Add GitHub Desktop to the system
  home.packages = with pkgs; [
    github-desktop
  ];
}
