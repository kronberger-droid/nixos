# The Claude Code sandbox account's home. Imported by
# system/security/agent-sandbox.nix, which owns the account itself; this
# file only fills the home, and only when that module is switched on.
#
# Modelled on kronberger-server.nix rather than kronberger.nix: shell, git,
# the Rust toolchain and the shared Claude Code config, none of the desktop.
# What this deliberately leaves out:
#   - programs.ssh: no cluster aliases and no addKeysToAgent. The account's
#     one key sits unencrypted in ~/.ssh and ssh finds it on its own.
#   - helix: the agent edits through its own tools.
{
  config,
  lib,
  pkgs,
  ...
}: {
  home-manager.users.claude = lib.mkIf config.security.agentSandbox.enable {
    imports = [
      ../shell/nushell.nix
      ../shell/git.nix
      ../shell/tools.nix
      ../editors/dev-tools.nix
      ../theming/base16-scheme.nix
      ../apps/claude-settings.nix
    ];

    home = {
      username = "claude";
      homeDirectory = "/home/claude";
      stateVersion = "26.11";
      # ai.nix's set minus inpdf: claude itself, plus node for the
      # npx-launched MCP servers the enabled plugins bring along.
      packages = with pkgs; [
        claude-code-bin
        nodejs
      ];
    };

    # git.nix sets ssh for gh, which is right for the primary user's key on
    # GitHub. This account has no key there: it authenticates with the
    # fine-grained token that extra_env.nu puts in GH_TOKEN, and gh's git
    # credential helper (on by default) hands that to git for https pushes.
    programs.gh.settings.git_protocol = lib.mkForce "https";

    # Everything else about Claude Code comes from claude-settings.nix, same
    # as the primary user. Only this account's CLAUDE.md gets an extra
    # section, on how to work from inside the sandbox.
    claude.claudeMd = lib.mkAfter (builtins.readFile ../apps/claude-md-sandbox.md);

    # Sessions started from claude.ai/code or the mobile app spawn here, as
    # this account, with no ssh in between. Linger (agent-sandbox.nix) keeps
    # it running without a login. It needs the account logged in to claude.ai
    # once (`claude-sandbox`, then `claude`); until then it exits and the
    # restart loop below just keeps trying, so the order of the two steps
    # does not matter.
    systemd.user.services.claude-remote-control = lib.mkIf config.security.agentSandbox.remoteControl.enable {
      Unit = {
        Description = "Claude Code Remote Control server";
        # Retry forever: the first failures are expected, before the login.
        StartLimitIntervalSec = 0;
      };
      Service = {
        WorkingDirectory = "%h/src";
        # A user unit starts with a bare PATH. The spawned sessions need the
        # same tools a login shell has: this profile, then the system's.
        Environment = ["PATH=/etc/profiles/per-user/claude/bin:/run/wrappers/bin:/run/current-system/sw/bin"];
        # Through a wrapper for the GitHub token. Interactive shells get it
        # from extra_env.nu, but nothing here starts a login shell, so the
        # spawned sessions would otherwise run with no GitHub credential.
        ExecStart = lib.getExe (pkgs.writeShellScriptBin "claude-remote-control" ''
          token=/run/secrets/claude-github-token
          if [ -r "$token" ]; then
            GH_TOKEN="$(< "$token")"
            export GH_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"
          fi
          exec ${lib.getExe' pkgs.claude-code-bin "claude"} remote-control
        '');
        Restart = "always";
        RestartSec = 30;
      };
      Install.WantedBy = ["default.target"];
    };

    programs.home-manager.enable = true;
  };
}
