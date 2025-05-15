{ pkgs, accentColor, backgroundColor, ... }:
{
  home.packages = with pkgs; [
    mako
  ];

  services = {
    mako = {
      enable = true;
      settings = {
        defaultTimeout = "10000";
        borderRadius = "8";
        borderColor = accentColor;
        backgroundColor = backgroundColor;
      };
    };
    # poweralertd.enable = true;
  };

}
