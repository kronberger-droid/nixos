# Sandboxing for agent runtimes, in two layers.
#
# The packages half is unconditional: claude-science refuses to start without
# bwrap on PATH, and its sandbox networking (like Claude Code's Bash sandbox on
# Linux) bridges through socat. Workstations get this through
# security/default.nix; the homeserver imports it directly.
#
# nixpkgs' bwrap is not setuid, so it relies on unprivileged user namespaces.
# NixOS leaves those on, and hardening.nix does not touch them. Keep it that
# way, or this package installs fine and then fails at runtime.
#
# The `enable` half is a dedicated unix account for Claude Code. Permission
# rules in home-manager/apps/claude.nix decide what the agent tries, not what
# it can do: a session running as the primary user can read ~/.ssh and talk
# to the oo7 agent socket, which signs for it whether or not the key file is
# hidden. Only a kernel boundary changes that, and a second uid is the
# lightest one that still leaves nix, cargo and the full toolchain usable.
# The built-in bubblewrap sandbox wraps Bash only; containers and microvms
# are too heavy for daily builds.
#
# What the account gets, and does not get:
#   - its own home at 750, group `claude`, with the primary user in that
#     group: Martin reads the agent's tree, the agent never reads his (the
#     primary home stays 700).
#   - its own ssh key, generated on first boot, no passphrase and no agent.
#     A key that cannot leave its own uid does not need an agent to guard
#     it. Server-side that key gets `restrict,from=` in authorized_keys.
#   - GitHub through a fine-grained token on Martin's account (agenix.nix,
#     `claude-github-token`), scoped repo by repo on the GitHub side. The
#     sandbox pushes over https, so its ssh key never touches GitHub.
#   - the vault, bind-mounted at the same path relative to $HOME so the
#     vault skill works unchanged, writable through default ACLs (see
#     claude-sandbox-vault-acl below).
#   - nix as an allowed user, not a trusted one: it may build, it may not
#     add substituters or push unsigned paths.
#   - no password, no authorized_keys, no sudo. The only way in is
#     `claude-sandbox` from the primary user's session, which is a
#     `machinectl shell` behind a polkit rule scoped to exactly that pair.
#
# Code comes back out the way a contributor's fork would: Martin adds
# /home/claude/src/<repo> as a remote and fetches from it (safe.directory in
# home-manager/shell/git.nix), reviews, and pushes with his own key. Nothing
# gives the agent a path into the primary home in return.
{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.security.agentSandbox;
  user = "claude";
  home = "/home/${user}";

  # The primary user's vault, from the account definition rather than a
  # rebuilt string, so it tracks any users.users.<name>.home override. The
  # tail matches vault.path in home-manager/apps/obsidian.nix.
  vaultRel = "Documents/notes/general-vault";
  vaultSrc = "${config.users.users.${username}.home}/${vaultRel}";
  vaultDst = "${home}/${vaultRel}";

  # `machinectl shell claude@` rather than `sudo -u claude -i`: machined runs
  # the shell through PAM as a real login, so logind hands the account its
  # own XDG_RUNTIME_DIR and `systemd --user`. Under sudo there is no session,
  # so anything socket-activated has nowhere to live. TERM is forwarded by
  # hand; machinectl starts from a clean environment and the shell would
  # otherwise come up as a dumb terminal.
  launcher = pkgs.writeShellScriptBin "claude-sandbox" ''
    set -eu
    args=(--setenv=TERM="''${TERM:-xterm-256color}")
    [ -n "''${COLORTERM:-}" ] && args+=(--setenv=COLORTERM="$COLORTERM")
    exec ${pkgs.systemd}/bin/machinectl shell "''${args[@]}" ${user}@ "$@"
  '';
in {
  imports = [../../home-manager/users/claude.nix];

  options.security.agentSandbox.enable = lib.mkEnableOption "a dedicated unix account for Claude Code";

  config = lib.mkMerge [
    {
      environment.systemPackages = with pkgs; [
        bubblewrap
        socat
      ];
    }

    (lib.mkIf cfg.enable {
      users.groups.${user} = {};
      users.users.${user} = {
        isNormalUser = true;
        createHome = true;
        group = user;
        homeMode = "750";
        description = "Claude Code sandbox";
        shell = pkgs.nushell;
      };
      users.users.${username}.extraGroups = [user];

      # nix-settings.nix limits the daemon to root and the primary user;
      # without this line every `nix build` in the sandbox is refused.
      nix.settings.allowed-users = [user];

      environment.systemPackages = [launcher];

      # machined checks host-shell with the target user in the action
      # details (src/machine/machine-dbus.c), so the grant can name both
      # ends: this user, opening a shell as the sandbox account, nobody
      # else and nothing else. Any other target still gets polkit's admin
      # prompt, same as before.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.machine1.host-shell" &&
              action.lookup("user") == "${user}" &&
              subject.user == "${username}") {
            return polkit.Result.YES;
          }
        });
      '';

      # The directories the bind mount and the agent's checkouts land in.
      # An activation script rather than tmpfiles: tmpfiles runs after
      # local-fs.target, by which time the mount unit has already created
      # its mountpoint chain as root, and a root-owned ~/Documents in the
      # sandbox home is not what anybody wants.
      system.activationScripts.claudeSandboxHome = lib.stringAfter ["users"] ''
        ${pkgs.coreutils}/bin/install -d -o ${user} -g ${user} -m 0755 \
          ${home}/Documents ${home}/Documents/notes ${home}/src
      '';

      # A bind mount resolves permissions on the vault's own inodes, never on
      # /home/<primary> above it, so the 700 there stays intact while the
      # vault inside is reachable. nofail: on a host where syncthing has not
      # delivered the vault yet the boot must not wait on it.
      fileSystems.${vaultDst} = {
        device = vaultSrc;
        fsType = "none";
        options = ["bind" "nofail"];
      };

      # Write access through POSIX ACLs rather than a shared group and
      # umask. A default ACL on every directory means a note created by
      # either user, Obsidian, or syncthing's temp-and-rename gets the group
      # entry on creation, umask notwithstanding. Recursive and run once per
      # boot so files that arrived while the rule was absent catch up. Two
      # things keep it honest: setfacl recomputes the mask, so the entry is
      # effective and not merely present, and the syncthing folder carries
      # ignorePerms (home-manager/apps/syncthing.nix), since a chmod 644 on
      # a synced file would otherwise clip the mask back to read-only.
      systemd.services.claude-sandbox-vault-acl = {
        description = "Grant the Claude Code sandbox user write access to the vault";
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathIsDirectory = vaultSrc;
        serviceConfig.Type = "oneshot";
        script = ''
          ${pkgs.acl}/bin/setfacl -R -m g:${user}:rwX,d:g:${user}:rwX ${lib.escapeShellArg vaultSrc}
        '';
      };

      # One ed25519 key per host, made where it will live. No passphrase: the
      # threat this account exists for is a session reading somebody else's
      # key, and this one is readable by its owner alone. The public half is
      # what goes into authorized_keys on the servers, with `restrict,from=`.
      systemd.services.claude-sandbox-ssh-key = {
        description = "Generate the Claude Code sandbox user's SSH key";
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathExists = "!${home}/.ssh/id_ed25519";
        serviceConfig = {
          Type = "oneshot";
          User = user;
          Group = user;
        };
        script = ''
          umask 077
          mkdir -p ${home}/.ssh
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" \
            -C "${user}@${config.networking.hostName}" -f ${home}/.ssh/id_ed25519
        '';
      };
    })
  ];
}
