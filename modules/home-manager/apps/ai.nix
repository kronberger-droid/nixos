{pkgs, ...}: {
  home.packages = with pkgs; [
    ollama
    claude-code
    gemini-cli
  ];

  # Symlink claude to ~/.local/bin for native installation check
  home.file.".local/bin/claude".source = "${pkgs.claude-code-bin}/bin/claude";
}
