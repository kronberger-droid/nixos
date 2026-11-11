# Matrix + WhatsApp bridge on homeserver

What runs, why it is built this way, and the traps hit on the way in.
Config: `modules/system/services/matrix.nix`. Client: Element desktop,
`modules/home-manager/apps/element.nix`.

## Shape

- **tuwunel** (Rust, RocksDB) as homeserver. `server_name` is
  `kron-berger.com` and permanent. Federation and registration are off.
- **mautrix-whatsapp** logs in as a WhatsApp linked device. The phone must
  come online at least every two weeks or WhatsApp unlinks it.
- Reachable on the tailnet only: tuwunel on 6167 (opened on `tailscale0`),
  and `tailscale serve` in front of it as `https://homeserver.tailc7340c.ts.net`.
  Element needs the HTTPS front; its `vector://` origin blocks plain http
  to anything but localhost.
- Double puppeting through mautrix's appservice method, so messages sent
  from the phone show up as `@kronberger`, not as a ghost.
- Bridge encryption off. WhatsApp's E2EE ends at the bridge on this box
  anyway, and tuwunel + mautrix encryption (MSC4190) is untested upstream.
  Element shows its "not encrypted" notices as a result.
- Pinned WhatsApp chats get `m.favourite`, archived ones `m.lowpriority`,
  once, when the portal is created.

## Why the registrations live in agenix

Both appservice registrations (the bridge's and the double-puppet one) are
agenix secrets that tuwunel loads at startup through `LoadCredential` and
`appservice_dir`. Registering by hand in the admin room cannot work with
deploy-rs: until tuwunel knows the bridge's token the bridge exits
(status 16), the switch reports a failed unit and deploy-rs rolls back.

The bridge's registration came from `mautrix-whatsapp -g` against this
config. Its namespaces follow `appservice.bot.username` and
`username_template`; changing either means regenerating it.

## Traps

- **libolm.** The default `mautrix-whatsapp` links it and nixpkgs marks it
  insecure, so the host does not evaluate. Built with `withGoolm = true`.
- **Forced system libraries.** The cargo setup hook exports
  `AWS_LC_SYS_USE_SYSTEM=1` and `JEMALLOC_OVERRIDE`; tuwunel 1.9.4 fails
  without `aws-lc` and an unprefixed jemalloc (backports-overlay.nix,
  nixpkgs #585169).
- **agenix and switch order.** With userborn, agenix installs secrets from a
  unit, and switch-to-configuration starts units one job each in no fixed
  order. `after` alone let tuwunel start against the previous agenix
  generation (CREDENTIALS, ENOENT). Fixed with `wants` + `after` on
  `agenix-chown.service`. radicale still has `after` only.
- **First account.** `admin_execute = ["users create-user kronberger"]`.
  tuwunel makes the first user admin and logs a generated password.
- **Sandboxed keyring clients.** libsecret inside nixpak sees
  `/.flatpak-info` and always uses the Secret portal; `SECRET_BACKEND` is
  only read when that check fails. oo7-portal 0.6.0 cannot write the key
  down libsecret's pipe, so it is backported to 0.7.1
  (backports-overlay.nix, nixpkgs #584231).

## Clients tried

FluffyChat (Dart SDK) worked once the portal was fixed but was dropped for
Element. iamb is Vim-only (modalkit); there is no Helix-style Matrix TUI.
The closest non-modal terminal option is WeeChat with weechat-matrix-rs,
which is not in nixpkgs. Element X needs simplified sliding sync, not
checked against tuwunel.

## Sources

- https://docs.mau.fi/bridges/go/whatsapp/authentication.html
- https://docs.mau.fi/bridges/general/double-puppeting.html
- https://docs.mau.fi/bridges/general/end-to-bridge-encryption.html
- https://matrix-construct.github.io/tuwunel/appservices.html
- tuwunel 1.9.4 source: `src/service/appservice/mod.rs`,
  `src/admin/user/create_user.rs`, `src/core/config/mod.rs`
- libsecret 0.21.8.2: `libsecret/secret-backend.c`
- oo7 0.6.0 vs 0.7.1: `portal/src/main.rs`
