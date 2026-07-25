{
  pkgs,
  inputs,
  ...
}: let
  # Kept in step with `base_url` in the site repo's config.toml. If the two
  # drift, the site still serves but every canonical link and the Atom feed
  # point at the wrong host.
  domain = "kron-berger.com";

  # From `cloudflared tunnel create website`. The cloudflared module keys its
  # systemd unit off this string, so the unit is named
  # cloudflared-tunnel-e16e5d38-196c-4da1-a0f9-cbdaf07413f6.service.
  # This is an identifier, not a secret — the secret is the credentials JSON.
  tunnelId = "e16e5d38-196c-4da1-a0f9-cbdaf07413f6";

  # The built site: a directory of static files in the nix store, produced by
  # the `website` flake input. Changing content means bumping that input, which
  # changes this path, which is what makes deploys atomic and rollbacks free.
  site = inputs.website.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Loopback only. Nothing on the LAN or the internet reaches nginx directly —
  # cloudflared is the sole client, and it runs on this host. This is why the
  # firewall's allowedTCPPorts list in configuration.nix needs no new entry.
  port = 8080;

  # nginx's `add_header` replaces rather than accumulates: one `add_header` in a
  # location block drops every header inherited from the server block. So the
  # headers cannot live at server level and be topped up per location — each
  # location has to carry the full set. nixpkgs runs gixy over the generated
  # config at build time and rejects exactly this mistake, which is how it got
  # caught rather than shipping as a quietly header-less /publications/.
  securityHeaders = ''
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
  '';
in {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    # No recommendedTlsSettings: TLS terminates at Cloudflare's edge, and the
    # hop from cloudflared to nginx never leaves loopback.

    virtualHosts.${domain} = {
      listen = [
        {
          addr = "127.0.0.1";
          inherit port;
        }
      ];
      root = site;

      # Only vhost on this nginx, so take anything cloudflared forwards
      # regardless of the Host header it carries.
      default = true;
      serverAliases = ["www.${domain}"];

      # A request for /blog with no trailing slash makes nginx 301 to the
      # directory form. By default it builds that Location header from its own
      # listen address, which here is plain HTTP on 127.0.0.1:8080 — nginx
      # cannot see that Cloudflare terminated TLS on 443, so visitors got
      # bounced to http://kron-berger.com:8080/blog/ and the browser flagged
      # the page as not secure. Relative redirects (Location: /blog/) leave the
      # scheme, host and port to the browser, which still has the real ones.
      #
      # This is the general shape of the problem with any origin behind a
      # terminating proxy, not something specific to Cloudflare.
      extraConfig = ''
        absolute_redirect off;
      '';

      locations."/" = {
        index = "index.html";
        # Zola emits directory-style URLs (/blog/some-post/index.html), so a
        # bare /blog/some-post has to fall through to the directory before 404.
        tryFiles = "$uri $uri/ =404";

        extraConfig =
          securityHeaders
          + ''
            # Filenames are not content-hashed — /style.css keeps its name
            # across rebuilds — so a long max-age would strand visitors on a
            # stale stylesheet after a deploy. `no-cache` does not mean "do not
            # cache", it means "cache but revalidate": nginx answers the
            # conditional request with a 304 off the ETag whenever the file is
            # unchanged, so the common case is a cheap header exchange rather
            # than a re-download.
            add_header Cache-Control "no-cache";
          '';
      };

      # PDFs are immutable once published: a paper does not change under its own
      # filename. Cache them hard, and publish revisions under a new name.
      #
      # Matched by extension, not by the /publications/ prefix. A prefix match
      # also catches /publications/index.html — the section listing — which would
      # pin the page announcing a new paper for 30 days, `immutable` meaning the
      # browser does not even revalidate. nginx checks regex locations after
      # prefix ones but lets them win, so this overrides `location /` for PDFs
      # and leaves every HTML page on no-cache.
      locations."~* \\.pdf$".extraConfig =
        securityHeaders
        + ''
          add_header Cache-Control "public, max-age=2592000, immutable";
        '';
    };
  };

  # Cloudflare Tunnel — cloudflared dials *out* to Cloudflare's edge and keeps
  # that connection open, so traffic arrives over a connection this host
  # established. No inbound port, no router forwarding, no ACME, and the home IP
  # is never published in DNS.
  #
  # The upstream module runs this under DynamicUser with systemd LoadCredential.
  # LoadCredential reads the file as root before dropping privileges, so the
  # root-owned 0400 agenix secret is readable without the static-user workaround
  # nix-serve needed (see the comment above users.users.nix-serve).
  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      credentialsFile = "/run/secrets/cloudflared-website";

      ingress = {
        ${domain} = "http://127.0.0.1:${toString port}";
        # Needs its own DNS route:
        #   cloudflared tunnel route dns website www.${domain}
        "www.${domain}" = "http://127.0.0.1:${toString port}";
      };

      # Catch-all for any hostname that resolves here without a matching rule.
      # cloudflared requires a terminating rule; 404 is the quiet answer.
      default = "http_status:404";
    };
  };
}
