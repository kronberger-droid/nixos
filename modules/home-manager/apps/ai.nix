{pkgs, ...}: {
  home.packages = with pkgs; [
    ollama
    claude-code-bin
    sox
    nodejs # needed for npx (MCP servers)
    inpdf # PDF search/extract MCP server (from overlay)
  ];
}
