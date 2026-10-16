# The uid split in services/flake-autoupdate.nix, checked in a VM: whatever
# the agent account runs, it must not reach the GitHub token or the job's
# state, while the job account keeps both. Fake tokens stand in for the
# agenix secrets, so the test needs neither the real ones nor the network.
{
  pkgs,
  inputs,
  overlays,
}:
pkgs.testers.runNixOSTest {
  name = "flake-autoupdate-isolation";
  node.specialArgs = {inherit inputs;};
  node.pkgsReadOnly = false;

  nodes.machine = {lib, ...}: {
    imports = [../modules/system/services/flake-autoupdate.nix];
    # The module declares its secrets for agenix; the test writes plain files
    # at the same paths instead, so only the option needs to exist.
    options.age.secrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };
    config = {
      nixpkgs.overlays = overlays;
      nixpkgs.config.allowUnfree = true;
      systemd.timers.flake-autoupdate.enable = false;
      virtualisation.memorySize = 2048;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed(
        "mkdir -p /run/secrets"
        " && echo GITHUB-SECRET > /run/secrets/flake-update-github-token"
        " && echo CLAUDE-SECRET > /run/secrets/flake-update-claude-token"
        " && chmod 0400 /run/secrets/*"
    )

    with subtest("the job holds its token and owns its state"):
        machine.succeed(
            "flake-autoupdate-as job /bin/sh -c '"
            "test \"$(cat $CREDENTIALS_DIRECTORY/github-token)\" = GITHUB-SECRET"
            " && mkdir -p $STATE_DIRECTORY/src"
            " && echo JOB-PRIVATE > $STATE_DIRECTORY/src/x'"
        )

    # A job step that is still running, so its credentials directory and
    # its environment exist while the agent probes for them.
    machine.succeed("flake-autoupdate-as job /bin/sh -c 'sleep 300' >/dev/null 2>&1 &")
    machine.wait_until_succeeds("systemctl list-units --type=service | grep -q run-")

    with subtest("the agent runs as its own account with only its token"):
        out = machine.succeed(
            "flake-autoupdate-as agent /bin/sh -c 'id -un; ls $CREDENTIALS_DIRECTORY; cat $CREDENTIALS_DIRECTORY/claude-token'"
        )
        assert "flake-update-agent" in out, out
        assert "CLAUDE-SECRET" in out, out
        assert "github" not in out, out

    with subtest("the agent cannot reach the job's token or state"):
        machine.fail("flake-autoupdate-as agent /bin/sh -c 'cat /var/lib/flake-update/src/x'")
        machine.fail("flake-autoupdate-as agent /bin/sh -c 'ls /var/lib/flake-update'")
        machine.fail("flake-autoupdate-as agent /bin/sh -c 'cat /run/secrets/flake-update-github-token'")
        machine.fail("flake-autoupdate-as agent /bin/sh -c 'cat /run/credentials/*/github-token'")
        machine.fail("flake-autoupdate-as agent /bin/sh -c 'cat /proc/*/environ | grep -aq GITHUB-SECRET'")
        # The hole the split closes: evaluation runs in the agent's own
        # process, so readFile has exactly the agent's reach. The first call
        # is the control: the same command works on a file it may read.
        machine.succeed(
            "flake-autoupdate-as agent /bin/sh -c "
            "\"nix-instantiate --eval -E 'builtins.readFile /etc/os-release'\""
        )
        machine.fail(
            "flake-autoupdate-as agent /bin/sh -c "
            "\"nix-instantiate --eval -E 'builtins.readFile /var/lib/flake-update/src/x'\""
        )
  '';
}
