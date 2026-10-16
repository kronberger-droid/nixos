{pkgs, ...}: {
  home.packages = with pkgs; [
    claude-code-bin
    nodejs # needed for npx (MCP servers)
    inpdf # PDF search/extract MCP server (from overlay)
  ];
}
