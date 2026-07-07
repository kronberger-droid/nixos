{
  pkgs,
  config,
  username,
  ...
}: {
  users.users.${username} = {
    createHome = true;
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.kronberger-password.path;
    description = "Kronberger";
    extraGroups = ["networkmanager" "wheel" "audio" "video" "dialout"];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = builtins.attrValues (import ../../shared/ssh-keys.nix);
  };

  environment = {
    shells = [pkgs.nushell];
    variables = {
      EDITOR = "hx";
    };
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    sudo-rs.enable = true;
  };
}
