# Syncthing ignore patterns, shared by the two modules that render them:
# modules/system/services/syncthing.nix (homeserver only) and
# modules/home-manager/apps/syncthing.nix (every host, via apps/default.nix).
# Both write the same ~/Documents/.stignore, so the patterns have to agree.
# Keeping them here is what stops the two copies drifting apart.
{
  # `notes/general-vault` is synced as its own folder, so exclude it from the
  # parent `documents` folder to avoid double-indexing every change.
  #
  # `/pictures` is anchored with a leading slash so it only covers the photo
  # library at the folder root; that library lives in Immich now and must not
  # come back into the sync set. Unanchored, it would match any directory
  # named `pictures` at any depth, including under `university`.
  documents = ''
    notes/general-vault
    /pictures
  '';
}
