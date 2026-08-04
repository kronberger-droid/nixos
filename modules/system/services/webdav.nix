{...}: let
  # hacdias/webdav's default. Nothing else on this host claims it.
  port = 6065;

  # Zotero appends "zotero/" to whatever URL you hand it and creates that
  # directory on first sync, so the server's root is the *parent*. Point it at
  # the collection directory itself and Zotero would write /var/lib/webdav/
  # zotero/zotero/.
  dataDir = "/var/lib/webdav";
in {
  # WebDAV server backing Zotero's file sync. Zotero splits sync in two: item
  # metadata always goes through zotero.org's API (their server is closed, so
  # there is nothing to self-host there), while *attachment files* — the PDFs,
  # and the only part that eats the 300 MB free quota — can be pointed at an
  # arbitrary WebDAV server. This is that server.
  #
  # Two limits worth remembering before debugging a "missing file": WebDAV only
  # applies to My Library, group library attachments always go to Zotero
  # storage; and the on-disk layout is a flat pile of <ItemKey>.zip /
  # <ItemKey>.prop pairs, not a browsable tree. It is a blob store.
  #
  # nginx was the other candidate, since this host already runs one. Its
  # built-in ngx_http_dav_module only implements PUT/DELETE/MKCOL/COPY/MOVE —
  # Zotero's "Verify Server" also needs PROPFIND and OPTIONS, which live in the
  # third-party nginx-dav-ext-module. Enabling that means a custom nginx build
  # (no binary cache, a local compile on every nginx bump) and a second vhost on
  # an nginx that is otherwise deliberately loopback-only for the Cloudflare
  # tunnel. A standalone daemon keeps those two exposures from touching.
  services.webdav = {
    enable = true;
    settings = {
      # Bound wide and restricted at the firewall rather than bound to the
      # tailscale0 address directly: that address is host-specific, and the
      # interface is not guaranteed to be up when this unit starts.
      address = "0.0.0.0";
      inherit port;
      directory = dataDir;

      # Deny by default; the one account below opts into full access. Without
      # this, `permissions` defaults to read-only *for everyone listed*, and
      # Zotero's first upload fails with a 403 that it reports as a generic
      # sync error.
      permissions = "none";

      users = [
        {
          # `settings` is rendered to YAML in the Nix store, which is
          # world-readable, so neither of these may be inline. The {env} prefix
          # is hacdias/webdav's own indirection, resolved at startup from the
          # process environment — which is what environmentFile below fills.
          username = "{env}ZOTERO_DAV_USER";
          password = "{env}ZOTERO_DAV_PASSWORD";
          permissions = "CRUD";
        }
      ];
    };

    # systemd reads EnvironmentFile= from the service manager, i.e. as root,
    # before dropping to User=webdav. So a root-owned 0400 agenix secret works
    # here with no ownership juggling — unlike radicale's htpasswd, which
    # radicale itself opens at runtime and therefore has to be owned by the
    # service user.
    environmentFile = "/run/secrets/webdav-zotero";
  };

  # The module sets no StateDirectory, so nothing creates the root for it.
  # 0750: the daemon needs it, nobody else does.
  #
  # The Z line is for the seeded collection: files rcloned in from the old
  # provider land owned by whoever ran the copy (root), and `d` only adjusts
  # the directory it names — not what is already inside it. Without this the
  # daemon can read the migrated attachments but not overwrite them, so reads
  # work and the first upload fails. Mode is `-` so only ownership is touched;
  # forcing a mode here would set the directory bit on every blob.
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 webdav webdav -"
    "Z ${dataDir} - webdav webdav -"
  ];

  # Tailnet only. Scoping to the interface rather than adding to the global
  # allowedTCPPorts keeps this off the LAN entirely — every Zotero client that
  # needs it is on the tailnet anyway, and the traffic is already WireGuard
  # encrypted, which is why plain HTTP is fine on the Zotero side.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [port];
}
