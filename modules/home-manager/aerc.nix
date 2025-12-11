{pkgs, ...}: {
  # Add oama for OAuth2 authentication with Gmail and packages for viewing emails
  home.packages = with pkgs; [
    oama
    dante # HTML to text converter
    catimg # Image viewer for terminal
    w3m # Alternative HTML viewer
  ];

  # Configure oama with OAuth credentials
  xdg.configFile."oama/config.yaml".text = ''
    ## oama configuration
    ## Using public OAuth credentials for Google and Microsoft

    encryption:
      tag: KEYRING

    services:
      google:
        client_id: 406964657835-aq8lmia8j95dhl1a2bvharmfk3t1hgqj.apps.googleusercontent.com
        client_secret: kSmqreRr0qwBWJgbf5Y-PjSU

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
        "text/html" = "${pkgs.dante}/bin/html2text";
        "image/*" = "${pkgs.catimg}/bin/catimg -w \${WIDTH} -";
      };
    };
    extraAccounts = {
      Personal = {
        source = "imaps://martin.kronberger%40gmx.at@imap.gmx.net:993";
        source-cred-cmd = "secret-tool lookup application aerc account GMX service email";
        outgoing = "smtp://martin.kronberger%40gmx.at@mail.gmx.net:587";
        outgoing-cred-cmd = "secret-tool lookup application aerc account GMX service email";
        default = "INBOX";
        from = "Martin Kronberger <martin.kronberger@gmx.at>";
        cache-headers = true;
      };
      Google = {
        source = "imaps+xoauth2://kronberger.industries%40gmail.com@imap.gmail.com:993";
        source-cred-cmd = "oama access kronberger.industries@gmail.com";
        outgoing = "smtp+xoauth2://kronberger.industries%40gmail.com@smtp.gmail.com:587";
        outgoing-cred-cmd = "oama access kronberger.industries@gmail.com";
        default = "INBOX";
        from = "Kronberger Industries <kronberger.industries@gmail.com>";
        cache-headers = true;
      };
      TUWien = {
        source = "imaps+xoauth2://e12202316%40student.tuwien.ac.at@outlook.office365.com:993";
        source-cred-cmd = "oama access e12202316@student.tuwien.ac.at";
        outgoing = "smtp+xoauth2://e12202316%40student.tuwien.ac.at@smtp.office365.com:587";
        outgoing-cred-cmd = "oama access e12202316@student.tuwien.ac.at";
        default = "INBOX";
        from = "Martin Kronberger <e12202316@student.tuwien.ac.at>";
        cache-headers = true;
      };
      upTUdate = {
        source = "imaps://mkronber%40intern.tuwien.ac.at@mail.intern.tuwien.ac.at:993";
        source-cred-cmd = "secret-tool lookup application aerc account upTUdate service email";
        outgoing = "smtp://kronber%40intern.tuwien.ac.at@mail.intern.tuwien.ac.at:587";
        outgoing-cred-cmd = "secret-tool lookup application aerc account upTUdate service email";
        default = "INBOX";
        from = "Martin Kronberger <kronberger@iap.tuwien.ac.at>";
        cache-headers = true;
      };
    };
  };
}
