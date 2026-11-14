{pkgs, ...}: {
  # himalaya 2.x, with a hand-written config. home-manager's programs.himalaya
  # module still renders the 1.x schema, which 2.x rejects.
  #
  # The password is never in this file or in the store: each account runs a
  # command that prints it from the agenix secret (security/agenix.nix, two
  # lines: address, then password). That also keeps it out of Claude's context,
  # since reading mail only needs `himalaya envelope list` and friends. Debug
  # and trace output echo the auth exchange, so claude.nix denies those flags.
  home.packages = [pkgs.himalaya];

  xdg.configFile."himalaya/config.toml".text = ''
    [accounts.gmx]
    default = true
    email = "martin.kronberger@gmx.at"
    display-name = "Martin Kronberger"

    mailbox.alias.inbox = "INBOX"
    mailbox.alias.sent = "Gesendet"
    mailbox.alias.drafts = "Entwürfe"
    mailbox.alias.trash = "Gelöscht"

    imap.server = "imap.gmx.net"
    imap.tls.provider = "rustls"
    imap.sasl.plain.username = "martin.kronberger@gmx.at"
    imap.sasl.plain.password.command = "sed -n 2p /run/secrets/gmx-mail-credentials"

    smtp.server = "mail.gmx.net"
    smtp.tls.provider = "rustls"
    smtp.sasl.plain.username = "martin.kronberger@gmx.at"
    smtp.sasl.plain.password.command = "sed -n 2p /run/secrets/gmx-mail-credentials"

    # TU Wien. Mail goes out and comes in as the institute alias, but the
    # login is the central account on the intern domain. IMAP is implicit TLS
    # on 993; SMTP has nothing on 465, so it is STARTTLS on 587. The server
    # advertises GSSAPI, NTLM and LOGIN only and rejects PLAIN, hence
    # sasl.login for SMTP.
    [accounts.tuwien]
    email = "kronberger@iap.tuwien.ac.at"
    display-name = "Martin Kronberger"

    mailbox.alias.inbox = "Inbox"
    mailbox.alias.sent = "Sent Items"
    mailbox.alias.drafts = "Drafts"
    mailbox.alias.trash = "Deleted Items"

    imap.server = "mail.tuwien.ac.at"
    imap.tls.provider = "rustls"
    imap.sasl.plain.username = "mkronber@intern.tuwien.ac.at"
    imap.sasl.plain.password.command = "cat /run/secrets/tuwien-mail-password"

    smtp.server = "smtp://mail.tuwien.ac.at:587"
    smtp.starttls = true
    smtp.tls.provider = "rustls"
    smtp.sasl.login.username = "mkronber@intern.tuwien.ac.at"
    smtp.sasl.login.password.command = "cat /run/secrets/tuwien-mail-password"
  '';
}
