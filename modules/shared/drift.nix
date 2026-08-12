# drift — a standalone git diff pager, not in nixpkgs as of 26.11.
#
# Packaging notes, since the dependency list is unusually kind for a Rust TUI:
#
#   - `uncurses` is a pure-Rust curses reimplementation, not a binding. Despite
#     the name it links no ncurses; its only non-Windows dep is libc.
#   - syntect is pulled with default-features = false + "default-fancy", i.e.
#     fancy-regex rather than onig. That skips the oniguruma/pkg-config/
#     RUSTONIG_SYSTEM_LIBONIG handling that bat-like tools usually need.
#   - No libgit2 or gix. drift shells out to the git binary (src/git.rs), which
#     is why the wrapper below puts git on PATH: nothing else guarantees it is
#     there when drift is launched as a pager from an arbitrary environment.
#   - The only *-sys crates in the lock come from `notify` (inotify-sys on
#     Linux), which is header-free libc bindings and needs no buildInputs.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  git,
}:
rustPlatform.buildRustPackage rec {
  pname = "drift";
  version = "0.0.5";

  src = fetchFromGitHub {
    owner = "aymanbagabas";
    repo = "drift";
    rev = "v${version}";
    hash = "sha256-oLyhSE9P6XmHRq+pffbevlMfCeY++gRMsmEXSCclldA=";
  };

  # Deliberately cargoHash rather than `cargoLock.lockFile = "${src}/Cargo.lock"`.
  # The lockFile form has to read a file out of `src` at eval time, which forces
  # import-from-derivation: every plain `nix eval` of a host that includes this
  # package would have to fetch the tarball before it could finish evaluating.
  # We evaluate all hosts routinely, so the one-time hash is the cheaper trade.
  # Bump it alongside `version` (build once, copy the hash from the mismatch).
  cargoHash = "sha256-OqXAkMKztCMXJDlZkxTn9l1LcOhvd1e2bixvyE/RSXg=";

  nativeBuildInputs = [makeWrapper];

  # [profile.release] sets panic = "abort", and libtest needs unwinding, so
  # `cargo test --release` cannot even link the harness. Run the tests against
  # the dev profile instead of dropping the check phase outright; it costs a
  # second compile of the tree but keeps upstream's tests actually running.
  checkType = "debug";

  # git::tests shell out to a real git to build fixture repos, so without this
  # two of the 40 tests fail on ENOENT. git also wants an identity before it
  # will commit, and the sandbox has neither a HOME nor a global config.
  nativeCheckInputs = [git];

  preCheck = ''
    export HOME=$(mktemp -d)
    git config --global user.email drift@example.com
    git config --global user.name drift
    git config --global init.defaultBranch main
  '';

  postInstall = ''
    wrapProgram $out/bin/drift --prefix PATH : ${lib.makeBinPath [git]}
  '';

  meta = {
    description = "Standalone git diff pager for the terminal, built on uncurses";
    homepage = "https://github.com/aymanbagabas/drift";
    license = lib.licenses.mit;
    mainProgram = "drift";
    platforms = lib.platforms.unix;
  };
}
