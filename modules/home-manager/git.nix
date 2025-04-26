{ pkgs, ... }:{
  home.packages = with pkgs; [
    github-desktop
    gh
  ];
  programs.git = {
    enable = true;
    userName = "kronberger-droid";
    userEmail = "kronberger@proton.me";

    lfs.enable = true;
    extraConfig = {
      filter.lfs.required = true;
      filter.lfs.clean = "git-lfs clean -- %f";
      filter.lfs.smudge = "git-lfs smudge -- %f";
      filter.lfs.process = "git-lfs filter-process";
    };
  };
}
