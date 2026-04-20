{pkgs, ...}: {
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
      signing.format = null;
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
        pull.rebase = true;
      };
    };
  };
}
