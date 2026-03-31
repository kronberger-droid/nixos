{pkgs, ...}: {
  home.packages = with pkgs; [
    ollama
    claude-code-bin
    gemini-cli
    nodejs # needed for npx (MCP servers)
    inpdf # PDF search/extract MCP server (from overlay)
  ];

  # Symlink claude to ~/.local/bin for native installation check
  home.file.".local/bin/claude".source = "${pkgs.claude-code-bin}/bin/claude";
}
