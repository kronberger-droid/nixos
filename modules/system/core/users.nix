{
  pkgs,
  config,
  lib,
  inputs,
  username,
  ...
}: let
  # Not an agenix secret. userborn aliases systemd-sysusers.service, which
  # agenix-install-secrets orders itself after, so an agenix path is missing
  # whenever userborn runs at boot. userborn skips a user whose
  # hashedPasswordFile it cannot read: a fresh install came up without this
  # account at all. The hash is root-owned and needs no user to exist, so it
  # is decrypted ahead of userborn instead.
  passwordFile = "/run/user-passwords/${username}";
  passwordSecret = "${inputs.self}/secrets/kronberger-password.age";
in {
  systemd.services.decrypt-user-password = {
    description = "Decrypt the login password hash for userborn";
    # Wanted, not required: if decryption fails, userborn still creates
    # every other account.
    wantedBy = ["sysinit.target" "userborn.service"];
    before = ["userborn.service"];
    unitConfig.DefaultDependencies = false;
    restartTriggers = [passwordSecret];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    # Same identities as agenix, skipping the ones this host lacks.
    script = ''
      identities=()
      for id in ${lib.escapeShellArgs config.age.identityPaths}; do
        if [ -r "$id" ]; then identities+=(-i "$id"); fi
      done
      mkdir -p ${dirOf passwordFile}
      ${config.age.ageBin} --decrypt "''${identities[@]}" -o ${passwordFile}.tmp ${passwordSecret}
      mv -f ${passwordFile}.tmp ${passwordFile}
    '';
  };

  users.users.${username} = {
    createHome = true;
    isNormalUser = true;
    hashedPasswordFile = passwordFile;
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
