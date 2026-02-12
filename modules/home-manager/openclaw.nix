{pkgs, ...}: {
  programs.openclaw = {
    enable = true;
    config = {
      gateway.mode = "local";
      channels.signal = {
        enabled = true;
        account = "<your-phone-number>"; # TODO: fill in your Signal phone number
        cliPath = "${pkgs.signal-cli}/bin/signal-cli";
        dmPolicy = "pairing";
      };
      secrets = {
        anthropicApiKeyFile = "/run/secrets/openclaw-anthropic-api-key";
      };
    };
  };

  home.packages = [pkgs.signal-cli];
}
