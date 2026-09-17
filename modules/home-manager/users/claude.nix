# The Claude Code sandbox account's home. Imported by
# system/security/agent-sandbox.nix, which owns the account itself; this
# file only fills the home, and only when that module is switched on.
#
# Modelled on kronberger-server.nix rather than kronberger.nix: shell, git,
# the Rust toolchain and the shared Claude Code config, none of the desktop.
# What this deliberately leaves out:
#   - programs.ssh: no cluster aliases and no addKeysToAgent. The account's
#     one key sits unencrypted in ~/.ssh and ssh finds it on its own.
#   - helix and neovim: the agent edits through its own tools.
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
      stateVersion = "25.05";
      # ai.nix's set minus ollama and sox: claude itself, plus node for the
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

    programs.home-manager.enable = true;
  };
}
