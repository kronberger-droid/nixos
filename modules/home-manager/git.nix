{ pkgs, ... }: {
  home.packages = with pkgs; [
    github-desktop
  ];
  programs.gh = {
    enable = true;
    settings = {
      git_protocoll = "ssh";
    };
  };
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "kronberger-droid";
        email = "kronberger@proton.me";
      };
      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = true;
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
