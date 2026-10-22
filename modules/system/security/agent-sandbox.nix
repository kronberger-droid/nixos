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
# /home/claude/src/<repo> as a remote and fetches from it with
# `git fetch-sandbox` (home-manager/shell/git.nix; deliberately no global
# safe.directory), reviews, and pushes with his own key. Nothing
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

  options.security.agentSandbox = {
    enable = lib.mkEnableOption "a dedicated unix account for Claude Code";

    # For a host nobody sits at, and only while asked for: see the
    # claude-remote-control unit below.
    remoteControl = {
      enable = lib.mkEnableOption "an on-demand `claude remote-control` server in the sandbox account, opened with `claude-sandbox-open`";
      maxDuration = lib.mkOption {
        type = lib.types.str;
        default = "12h";
        description = "Longest window `claude-sandbox-open` accepts, as a systemd time span.";
      };
    };

    egressRules = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = "ip46tables -A claude-sandbox-out -o docker0 -j REJECT";
      description = ''
        iptables commands that fill the `claude-sandbox-out` chain, which
        every packet the sandbox account or a nix build user sends passes
        through. The module creates, flushes and jumps to the chain; hosts
        only say what it rejects. Empty means no chain.
      '';
    };
  };

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

      # The launcher forwards TERM, so the sandbox shell sees `xterm-rio`,
      # and rio's terminfo lives in the primary user's home-manager profile
      # where this account cannot read it. Install it system-wide. Not
      # enableAllTerminfo: that builds every listed emulator just for its
      # terminfo, so one broken package (urxvt under GCC 16) fails the
      # whole system build.
      environment.systemPackages = [launcher pkgs.rio.terminfo];

      # machined checks host-shell with the target user in the action
      # details (src/machine/machine-dbus.c), so the grant can name both
      # ends: this user, opening a shell as the sandbox account, nobody
      # else and nothing else. Any other target still gets polkit's admin
      # prompt, same as before.
      #
      # Enabled here, not left to the host: the workstations get polkit from
      # core/users.nix, the homeserver had none, and without it the rule
      # never runs and machined refuses the shell outright.
      security.polkit.enable = true;
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.machine1.host-shell" &&
              action.lookup("user") == "${user}" &&
              subject.user == "${username}") {
            return polkit.Result.YES;
          }
        });
      '';

      # The directories the bind mount and the agent's checkouts land in,
      # the same way userborn makes the home itself. Not an activation
      # script: under userborn (core/activation.nix) accounts are created by
      # userborn.service, after every activation script has run, so a
      # script here sees no `claude` user. Sequence at boot: the mount unit
      # mkdirs its mountpoint chain as root, then systemd-tmpfiles-setup
      # (after local-fs.target) hits these rules, and `d` adjusts owner and
      # mode on a directory that already exists. Net effect is the same as
      # creating them first.
      systemd.tmpfiles.settings."10-claude-sandbox" = let
        owned = {
          d = {
            mode = "0755";
            inherit user;
            group = user;
          };
        };
      in {
        "${home}/Documents" = owned;
        "${home}/Documents/notes" = owned;
        "${home}/src" = owned;
      };

      # The source side needs the same treatment. For a bind mount systemd
      # also mkdirs the source when it is missing, as root. On a fresh host,
      # before syncthing or a restore has delivered the vault, that leaves
      # ~/Documents, ~/Documents/notes and the vault root owned by root, and
      # syncthing then cannot write anywhere in the documents folder. The
      # vault itself kept working only through the ACL below. No mode: with
      # one, tmpfiles would chmod the vault root on every activation and clip
      # its ACL mask to r-x. Left unset, a missing directory is still created
      # 0755 and an existing one only has its owner fixed.
      systemd.tmpfiles.settings."10-claude-sandbox-source" = let
        primary = config.users.users.${username};
        owned = {
          d = {
            user = username;
            inherit (primary) group;
          };
        };
      in {
        "${primary.home}/Documents" = owned;
        "${primary.home}/Documents/notes" = owned;
        ${vaultSrc} = owned;
      };

      # A bind mount resolves permissions on the vault's own inodes, never on
      # /home/<primary> above it, so the 700 there stays intact while the
      # vault inside is reachable. nofail: on a host where syncthing has not
      # delivered the vault yet the boot must not wait on it.
      fileSystems.${vaultDst} = {
        device = vaultSrc;
        fsType = "none";
        options = ["bind" "nofail"];
      };
      # `.obsidian` read-only in this view, on top of the ACL strip below.
      # The ACLs alone leave a gap: the agent has write on the vault root,
      # and renaming a directory within the same parent needs write on the
      # parent only, so `mv .obsidian x; mkdir .obsidian` would hand it a
      # fresh plugin directory (the root's default ACL) until the next strip.
      # A mountpoint cannot be renamed (EBUSY) and this one is not writable.
      # The primary user reaches the vault through its own path, unaffected.
      fileSystems."${vaultDst}/.obsidian" = {
        device = "${vaultSrc}/.obsidian";
        fsType = "none";
        options = ["bind" "ro" "nofail"];
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
      #
      # Except `.obsidian/`. Obsidian loads the plugins there as Martin, so
      # write access to it is code execution as him, and syncthing would
      # carry a tampered plugin to every device. Removing the entries there
      # also drops the default ACL, so files created inside later stay
      # closed. The vault root's own default still applies to a freshly made
      # `.obsidian`, which the next run (every boot, every change to this
      # unit) strips again; the read-only mount above keeps it from being
      # swapped out in between.
      # Mode bits still apply, so the agent keeps whatever read access the
      # files give everyone.
      systemd.services.claude-sandbox-vault-acl = {
        description = "Grant the Claude Code sandbox user write access to the vault";
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathIsDirectory = vaultSrc;
        # Stays active after the run, so a switch that changes the script
        # restarts it instead of waiting for the next boot.
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          vault=${lib.escapeShellArg vaultSrc}
          ${pkgs.acl}/bin/setfacl -R -m g:${user}:rwX,d:g:${user}:rwX "$vault"
          if [ -d "$vault/.obsidian" ]; then
            ${pkgs.acl}/bin/setfacl -R -x g:${user},d:g:${user} "$vault/.obsidian"
          fi
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

    # The egress chain. Own chain, flushed on reload, with the OUTPUT jumps
    # added once, since nixos-fw never flushes OUTPUT and a plain -A there
    # would stack. Per family, as ip46tables only returns the v6 half's
    # status. nixbld as well as this account: the agent is an allowed nix
    # user, and a fixed-output build it asks for runs as nixbld* with the
    # host's network, around a uid match.
    (lib.mkIf (cfg.enable && cfg.egressRules != "") {
      networking.firewall.extraCommands = ''
        ip46tables -N claude-sandbox-out 2>/dev/null || true
        ip46tables -F claude-sandbox-out
        ${cfg.egressRules}
        for ipt in iptables ip6tables; do
          for match in "--uid-owner ${user}" "--gid-owner nixbld"; do
            $ipt -w -C OUTPUT -m owner $match -j claude-sandbox-out 2>/dev/null \
              || $ipt -w -A OUTPUT -m owner $match -j claude-sandbox-out
          done
        done
      '';
      networking.firewall.extraStopCommands = ''
        ip46tables -F claude-sandbox-out 2>/dev/null || true
      '';
    })

    # Remote Control as a window rather than a fixture. Sessions started from
    # claude.ai/code or the mobile app spawn as this account, with no ssh in
    # between, so while the server runs anyone holding the claude.ai login
    # has a shell here. It runs only between `claude-sandbox-open` and its
    # timer (or `claude-sandbox-close`); nothing starts it at boot, so a
    # reboot closes it too.
    #
    # A system unit with User=, not a user unit: LoadCredential in a user
    # unit is read by the user manager, i.e. as this account, so the secret
    # would have to be readable by it at all times. Here systemd reads it as
    # root, and the copy in the RuntimeDirectory is where interactive shells
    # (extra_env.nu) and the spawned sessions find it. systemd removes that
    # directory when the unit stops, so the token is gone with the window.
    # Stopping the unit also ends every session in its cgroup.
    (lib.mkIf (cfg.enable && cfg.remoteControl.enable) {
      systemd.services.claude-remote-control = {
        description = "Claude Code Remote Control server (on demand)";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        # Retry for as long as the window lasts: before the account's first
        # claude.ai login (`claude-sandbox`, then `claude`) it just exits.
        startLimitIntervalSec = 0;
        # The spawned sessions need the tools a login shell has: this
        # account's profile, then the system's. Forced, since the unit's
        # default PATH is NixOS's short service path.
        environment.PATH = lib.mkForce "/etc/profiles/per-user/${user}/bin:/run/wrappers/bin:/run/current-system/sw/bin";
        serviceConfig = {
          User = user;
          Group = user;
          WorkingDirectory = "${home}/src";
          LoadCredential = lib.optional (config.age.secrets ? claude-github-token) "github-token:${config.age.secrets.claude-github-token.path}";
          RuntimeDirectory = "claude-sandbox";
          RuntimeDirectoryMode = "0700";
          ExecStart = lib.getExe (pkgs.writeShellScriptBin "claude-remote-control" ''
            if [ -r "''${CREDENTIALS_DIRECTORY:-/nonexistent}/github-token" ]; then
              install -m 0400 "$CREDENTIALS_DIRECTORY/github-token" "$RUNTIME_DIRECTORY/github-token"
              GH_TOKEN="$(< "$RUNTIME_DIRECTORY/github-token")"
              export GH_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"
            fi
            exec ${lib.getExe' pkgs.claude-code-bin "claude"} remote-control
          '');
          Restart = "always";
          RestartSec = 30;
        };
      };

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "claude-sandbox-open" ''
          set -eu
          if [ "$(id -u)" -ne 0 ]; then exec /run/wrappers/bin/sudo "$0" "$@"; fi
          span="''${1:-2h}"
          secs() { ${pkgs.systemd}/bin/systemd-analyze timespan "$1" | ${pkgs.gawk}/bin/awk '/μs:/ { print int($2 / 1000000) }'; }
          # Empty on a parse error: the pipeline's status is awk's, not
          # systemd-analyze's.
          want=$(secs "$span" 2>/dev/null)
          if [ -z "$want" ] || [ "$want" -le 0 ]; then
            echo "claude-sandbox-open: not a time span: $span" >&2
            exit 2
          fi
          max=$(secs ${lib.escapeShellArg cfg.remoteControl.maxDuration})
          if [ "$want" -gt "$max" ]; then
            echo "claude-sandbox-open: capped at ${cfg.remoteControl.maxDuration}" >&2
            want=$max
          fi
          # Replace any earlier close timer, so reopening sets a fresh end; a
          # failed leftover would block reusing the transient unit's name.
          ${pkgs.systemd}/bin/systemctl stop claude-sandbox-close.timer 2>/dev/null || true
          ${pkgs.systemd}/bin/systemctl reset-failed claude-sandbox-close.timer claude-sandbox-close.service 2>/dev/null || true
          ${pkgs.systemd}/bin/systemctl start claude-remote-control.service
          ${pkgs.systemd}/bin/systemd-run --quiet --unit=claude-sandbox-close \
            --on-active="''${want}s" --timer-property=AccuracySec=1s \
            ${pkgs.systemd}/bin/systemctl stop claude-remote-control.service
          echo "Sandbox open until $(date -d "+''${want} seconds" '+%H:%M'). Close early: claude-sandbox-close"
        '')
        (pkgs.writeShellScriptBin "claude-sandbox-close" ''
          set -eu
          if [ "$(id -u)" -ne 0 ]; then exec /run/wrappers/bin/sudo "$0" "$@"; fi
          ${pkgs.systemd}/bin/systemctl stop claude-sandbox-close.timer 2>/dev/null || true
          ${pkgs.systemd}/bin/systemctl stop claude-remote-control.service
          echo "Sandbox closed."
        '')
      ];
    })
  ];
}
