# Syncthing ignore patterns, shared by the two modules that configure folders:
# modules/system/services/syncthing.nix (homeserver only) and
# modules/home-manager/apps/syncthing.nix (every other host, via apps/default.nix).
# No host runs both, but they describe the same folders, so the patterns have to
# agree. Keeping them here is what stops the two copies drifting apart.
#
# These go out as `ignorePatterns`, which the syncthing module POSTs to
# /rest/db/ignores. Syncthing then writes .stignore itself, as a regular file.
# Do not go back to placing .stignore via home.file or tmpfiles: both produce a
# symlink into the store, and Syncthing 2.x opens .stignore with O_NOFOLLOW, so
# it fails the read with ELOOP and silently falls back to ignoring nothing.
#
# Comment lines use `//`. `#` is not a comment in .stignore; it is a pattern
# matching a file whose name starts with `#`.
{
  documents = [
    "// The vault is its own Syncthing folder, so excluding it here avoids"
    "// double-indexing every change."
    "notes/general-vault"

    "// Anchored with a leading slash so it only covers the photo library at the"
    "// folder root; that library lives in Immich now and must not come back into"
    "// the sync set. Unanchored, it would match any directory named `pictures` at"
    "// any depth, including under `university`."
    "/pictures"
  ];

  generalVault = [
    "// Device-local Obsidian state."
    ".obsidian/workspace.json"
    ".obsidian/workspace-mobile.json"
    ".obsidian/cache"
    ".obsidian/cache.json"

    "// Rewritten by the obsidianAccentColor activation script, on every host, at"
    "// every activation. Two hosts activating between syncs each register a local"
    "// edit and Syncthing has no way to reconcile them, so this produced a steady"
    "// drip of appearance.sync-conflict-* files. The accent is derived from each"
    "// host's own base16 scheme, so it is device-local by nature and there is"
    "// nothing to gain from syncing it."
    ".obsidian/appearance.json"

    "// Trash and OS junk."
    ".trash/"
    ".DS_Store"

    "// Syncthing conflict files — never re-sync them."
    "*.sync-conflict-*"
  ];
}
