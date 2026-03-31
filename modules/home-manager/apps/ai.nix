{pkgs, ...}: {
  home.packages = with pkgs; [
    ollama
    claude-code-bin
    gemini-cli
    nodejs # needed for npx (MCP servers)
    inpdf # PDF search/extract MCP server (from overlay)
  ];
}
