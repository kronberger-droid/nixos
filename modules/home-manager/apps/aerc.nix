{pkgs, ...}: {
  # oama supplies OAuth2 access tokens for the office365 (TUWien) account.
  # The rest are terminal viewers for HTML / inline images.
  home.packages = with pkgs; [
    oama
    catimg # inline image viewer for the terminal
    w3m # alternative HTML viewer
    html2text # HTML to plain text
  ];

  # oama OAuth client config — public Microsoft app credentials (not secret).
  # The token itself lives in the keyring (KEYRING) and is refreshed by oama;
  # bootstrap once with:
  #   oama authorize microsoft e12202316@student.tuwien.ac.at
  xdg.configFile."oama/config.yaml".text = ''
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

  programs.aerc = {
    enable = true;
    extraConfig = {
      general = {
        unsafe-accounts-conf = true;
      };
      viewer = {
        pager = "less -R";
      };
      filters = {
        "text/plain" = "cat";
        "text/html" = "${pkgs.html2text}/bin/html2text";
        "image/*" = "${pkgs.catimg}/bin/catimg -w \${WIDTH} -";
      };
    };
    extraAccounts = {
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
    };
  };
}
