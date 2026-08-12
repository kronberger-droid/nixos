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

  # Lets `theme` name a .tmTheme file on disk. Both the built-in palettes and
  # syntect's bundled set are fixed at compile time, so without this there is
  # no way to highlight with a palette drift wasn't compiled against — and all
  # of its bundled options are visibly duller than our base16 scheme (mean
  # saturation 0.29-0.38 against ours at 0.50). Consumed by the generated
  # theme in modules/home-manager/shell/drift.nix.
  #
  # Not upstream: there is no issue for it (#7/#10 are a theme *picker*), so
  # this is a local feature, not a backport. Rebase on version bumps; if it
  # ever stops applying, dropping it costs syntax color fidelity, nothing else.
  patches = [./drift-tmtheme-path.patch];

  nativeBuildInputs = [makeWrapper];

  # [profile.release] sets panic = "abort", and libtest needs unwinding, so
  # `cargo test --release` cannot even link the harness. Run the tests against
  # the dev profile instead of dropping the check phase outright; it costs a
  # second compile of the tree but keeps upstream's tests actually running.
  checkType = "debug";

  # all_includes_untracked and rev_single_commit_renders_patch each save the cwd,
  # chdir into their own fixture repo, chdir back, then delete it. cwd is
  # per-process and libtest is threaded, so on a machine with enough cores one
  # test's saved cwd is the other's fixture, already removed by the time it
  # restores, and rev_single_commit_renders_patch dies at src/git.rs:338 with
  # ENOENT. Serializing is the honest fix: the flag sets RUST_TEST_THREADS=1,
  # and 40 tests that finish in 3.5s can afford it. Drop this once the fixtures
  # stop leaning on the process cwd.
  dontUseCargoParallelTests = true;

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
