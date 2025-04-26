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
      init = {
        defaultBranch = "main";
      };
      filter.lfs = {
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
      };
    };
  };
}
