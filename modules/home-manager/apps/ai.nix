{pkgs, ...}: {
  # No claude-code-bin: Claude Code runs in the sandbox account only, and
  # `claude` here is the launcher from system/security/agent-sandbox.nix.
  home.packages = with pkgs; [
    pi-coding-agent
    nodejs # needed for npx (MCP servers)
    inpdf # PDF search/extract MCP server (from overlay)
  ];

  # pi auto-discovers global extensions here; `/helix` toggles it at runtime.
  home.file.".pi/agent/extensions/helix-mode.ts".source = ./pi/helix-mode.ts;
}
