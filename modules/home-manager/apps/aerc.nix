{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.aerc;
in {
  # Off by default — upTUdate now covers the TUWien mail. Flip on if the
  # office365 account is ever needed again (also pulls in oama + its config).
  options.aerc.tuwien.enable =
    lib.mkEnableOption "the TUWien office365 account (XOAUTH2 via oama)";

  config = {
    # Terminal viewers for HTML / inline images. oama supplies OAuth2 access
    # tokens for the office365 account and is only needed when it's enabled.
    home.packages = with pkgs;
      [
        catimg # inline image viewer for the terminal
        w3m # HTML viewer; also backs aerc's bundled `html` filter
        html2text # HTML to plain text
        pandoc # markdown -> HTML for the multipart-converter (compose in md)
      ]
      ++ lib.optional cfg.tuwien.enable oama;

    # oama OAuth client config — public Microsoft app credentials (not secret).
    # The token itself lives in the keyring (KEYRING) and is refreshed by oama;
    # bootstrap once with:
    #   oama authorize microsoft e12202316@student.tuwien.ac.at
    xdg.configFile = lib.mkIf cfg.tuwien.enable {
      "oama/config.yaml".text = ''
        encryption:
          tag: KEYRING

        services:
          microsoft:
            client_id: 08162f7c-0fd2-4200-a84a-f25a4db0b584
            client_secret: 'TxRBilcHdC6WGBee]fs?QR:SJ8nI[g82' # notsecret - public OAuth credentials
            auth_endpoint: https://login.microsoftonline.com/common/oauth2/v2.0/authorize
            token_endpoint: https://login.microsoftonline.com/common/oauth2/v2.0/token
            redirect_uri: http://localhost:45355
            auth_scope: https://outlook.office.com/IMAP.AccessAsUser.All https://outlook.office.com/SMTP.Send offline_access
      '';
    };

    programs.aerc = {
      enable = true;
      extraConfig = {
        general = {
          unsafe-accounts-conf = true;
          # Default dir for :save on attachments.
          default-save-path = "~/Downloads";
        };
        ui = {
          # Group replies into threads in the message list.
          threading-enabled = true;
        };
        viewer = {
          pager = "less -R";
        };
        compose = {
          # Edit To/Cc/Bcc/Subject as plain lines at the top of the buffer in
          # the editor, instead of aerc's modal header prompts. Also makes the
          # helix `mail` grammar highlight correctly (real header block present).
          edit-headers = true;
          # Contact autocomplete for address headers, backed by khard (see
          # apps/contacts.nix). Reads the vdir synced from Radicale.
          address-book-cmd = "khard email --parsable %s";
        };
        filters = {
          # Bundled aerc filters: `colorize` adds quote/diff/url coloring to
          # plain text; `html` renders via w3m (nicer than html2text dumps).
          "text/plain" = "${pkgs.aerc}/libexec/aerc/filters/colorize";
          "text/html" = "${pkgs.aerc}/libexec/aerc/filters/html";
          "image/*" = "${pkgs.catimg}/bin/catimg -w \${WIDTH} -";
        };
        # Compose the body as Markdown (text/plain, stays readable as-is), then
        # `:multipart text/html` adds a rendered HTML alternative on send.
        multipart-converters = {
          "text/html" = "${pkgs.pandoc}/bin/pandoc -f markdown -t html --standalone";
        };
      };
      extraAccounts =
        {
          # Password from agenix (declarative). See modules/system/security/agenix.nix.
          Personal = {
            source = "imaps://martin.kronberger%40gmx.at@imap.gmx.net:993";
            source-cred-cmd = "${pkgs.coreutils}/bin/cat /run/secrets/aerc-gmx-password";
            outgoing = "smtp://martin.kronberger%40gmx.at@mail.gmx.net:587";
            outgoing-cred-cmd = "${pkgs.coreutils}/bin/cat /run/secrets/aerc-gmx-password";
            default = "INBOX";
            from = "Martin Kronberger <martin.kronberger@gmx.at>";
            cache-headers = true;
          };
          # Password from agenix (declarative).
          upTUdate = {
            source = "imaps://mkronber%40intern.tuwien.ac.at@mail.intern.tuwien.ac.at:993";
            source-cred-cmd = "${pkgs.coreutils}/bin/cat /run/secrets/aerc-uptudate-password";
            outgoing = "smtp://kronber%40intern.tuwien.ac.at@mail.intern.tuwien.ac.at:587";
            outgoing-cred-cmd = "${pkgs.coreutils}/bin/cat /run/secrets/aerc-uptudate-password";
            default = "INBOX";
            from = "Martin Kronberger <kronberger@iap.tuwien.ac.at>";
            cache-headers = true;
          };
        }
        // lib.optionalAttrs cfg.tuwien.enable {
          # XOAUTH2 via oama — token in keyring, not declarative.
          TUWien = {
            source = "imaps+xoauth2://e12202316%40student.tuwien.ac.at@outlook.office365.com:993";
            source-cred-cmd = "oama access e12202316@student.tuwien.ac.at";
            outgoing = "smtp+xoauth2://e12202316%40student.tuwien.ac.at@smtp.office365.com:587";
            outgoing-cred-cmd = "oama access e12202316@student.tuwien.ac.at";
            default = "INBOX";
            from = "Martin Kronberger <e12202316@student.tuwien.ac.at>";
            cache-headers = true;
          };
        };
    };
  };
}
