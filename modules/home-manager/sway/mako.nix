{ pkgs, accentColor, backgroundColor, ... }:
{
  home.packages = with pkgs; [
    mako
  ];

  services = {
    mako = {
      enable = true;
      defaultTimeout = 10000;
      borderRadius = 8;
      borderColor = accentColor;
      backgroundColor = backgroundColor + "CC";
    };
    poweralertd.enable = true;
  };

}
