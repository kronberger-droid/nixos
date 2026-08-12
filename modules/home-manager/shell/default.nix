{...}: {
  imports = [
    ./nushell.nix
    ./git.nix
    ./tools.nix
    # Standalone rather than a delta replacement: delta stays wired in as git's
    # `pager.diff` (it reads a diff on stdin), while drift is its own command
    # that runs git itself. `drift` for the browsing/watch TUI, `git diff` for
    # delta.
    ./drift.nix
  ];
}
