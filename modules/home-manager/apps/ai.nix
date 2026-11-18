{pkgs, ...}: {
  home.packages = with pkgs; [
    claude-code-bin
    pi-coding-agent
    nodejs # needed for npx (MCP servers)
    inpdf # PDF search/extract MCP server (from overlay)
  ];

  # pi auto-discovers global extensions here; `/helix` toggles it at runtime.
  home.file.".pi/agent/extensions/helix-mode.ts".source = ./pi/helix-mode.ts;
}
