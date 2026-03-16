{pkgs, ...}: {
  home.packages = with pkgs; [
    github-desktop
  ];

  programs = {
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        side-by-side = true;
        syntax-theme = "base16";
      };
    };

    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };

    git = {
      enable = true;
      lfs.enable = true;
      ignores = [
        ".rumdl_cache"
        ".claude/settings.local.json"
        ".direnv"
        ".envrc"
      ];
      settings = {
        user = {
          name = "kronberger-droid";
          email = "kronberger@proton.me";
        };
        init.defaultBranch = "main";
        url."git@github.com:".insteadOf = "https://github.com/";
        pull.rebase = true;
        filter.lfs = {
          required = true;
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
          process = "git-lfs filter-process";
        };
      };
    };
  };
}
