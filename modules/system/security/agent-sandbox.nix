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
#     primary home stays closed to everyone but him).
#   - read-only access to ~/Projects through ACLs
#     (claude-sandbox-read-acl below); everything else in the primary home
#     stays closed, and nothing in those trees is writable.
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
#   - nothing else of the primary user's or root's, except for a while and
#     on approval: agent-sandbox-grants.nix, asked for from inside with
#     `claude-sandbox-request`.
#   - no password, no authorized_keys, no sudo. The only way in is
#     `claude-sandbox` from the primary user's session, which is a
#     `machinectl shell` behind a polkit rule scoped to exactly that pair.
#
# The other direction is closed as well: the primary user has no Claude Code
# of his own. `claude` in his profile is claude-enter.nu, which opens the
# session in this account, and the real binary is installed for the sandbox
# account alone (home-manager/users/claude.nix). Do not add claude-code-bin
# to a host's systemPackages or to the primary user's home: either puts the
# real one back on his PATH.
#
# Code comes back out the way a contributor's fork would. The agent's
# checkouts mirror his ~/Projects under /home/claude/Projects (`claude`, i.e.
# claude-enter.nu, maps one to the other, clones on demand and keeps a
# `sandbox` remote in his repo pointed at the checkout). Martin fetches from
# it with `git fetch-sandbox` (home-manager/shell/git.nix; deliberately no
# global safe.directory), reviews, and pushes with his own key. The agent's only
# way into the primary home is the read-only ACLs above.
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}: let
  cfg = config.security.agentSandbox;
  user = "claude";
  home = "/home/${user}";
  # The longest Remote Control window `claude-sandbox-open` grants.
  maxWindow = "12h";

  # The primary user's vault, from the account definition rather than a
  # rebuilt string, so it tracks any users.users.<name>.home override. The
  # tail matches vault.path in home-manager/apps/obsidian.nix.
  vaultRel = "Documents/notes/general-vault";
  primaryHome = config.users.users.${username}.home;
  vaultSrc = "${primaryHome}/${vaultRel}";
  # What the sandbox reads of the primary home: claude-sandbox-read-acl.
  sharedTrees = ["${primaryHome}/Projects"];
  vaultDst = "${home}/${vaultRel}";

  # `machinectl shell claude@` rather than `sudo -u claude -i`: machined runs
  # the shell through PAM as a real login, so logind hands the account its
  # own XDG_RUNTIME_DIR and `systemd --user`. Under sudo there is no session,
  # so anything socket-activated has nowhere to live. TERM is forwarded by
  # hand; machinectl starts from a clean environment and the shell would
  # otherwise come up as a dumb terminal.
  #
  # Quiet when handed a command: machinectl's "Connected to the local host"
  # and "Connection terminated" lines belong around a shell somebody types
  # into, not around the output of one program.
  launcher = pkgs.writeShellScriptBin "claude-sandbox" ''
    set -eu
    args=(--setenv=TERM="''${TERM:-xterm-256color}")
    [ -n "''${COLORTERM:-}" ] && args+=(--setenv=COLORTERM="$COLORTERM")
    [ $# -gt 0 ] && args+=(--quiet)
    exec ${pkgs.systemd}/bin/machinectl shell "''${args[@]}" ${user}@ ${session} "$@"
  '';

  # What the launcher starts on the far side: the given command, or a login
  # shell, on a pty of the account's own.
  #
  # machined passes the shell its pty as file descriptors, and systemd only
  # chowns a terminal it opened itself through StandardInput=tty
  # (exec-invoke.c). The session's pty therefore stays root:tty 620. The
  # inherited descriptors work, but opening /dev/stdin, /dev/stdout or
  # /dev/stderr by path is refused, and home-manager's direnv hook does that
  # on every prompt (`e> /dev/stderr`). `script` allocates a second pty as
  # this user and relays bytes and window size, so nothing needs to know.
  #
  # `script -c` runs its command through $SHELL, which here is nu; it gets
  # bash for the one line that restores SHELL and execs the real argv.
  #
  # `script` runs as a child of this wrapper, never exec'd in its place.
  # systemd forks its (sd-pam) helper as a child of the session's main
  # process, and util-linux's `script` (2.42.4, ul_pty_wait_for_child)
  # reaps with `waitpid(-1, WNOHANG)` in a loop that only ends on an
  # error. With a child of its own that it never started still alive, that
  # returns 0 forever: `script` spins after its command has exited and the
  # caller's terminal never comes back.
  session = pkgs.writeShellScript "claude-sandbox-session" ''
    shell="''${SHELL:-/run/current-system/sw/bin/nu}"
    [ $# -gt 0 ] || set -- "$shell" -l
    printf -v cmd '%q ' "$@"
    printf -v restore 'SHELL=%q' "$shell"
    SHELL=${pkgs.runtimeShell} ${pkgs.util-linux}/bin/script \
      --quiet --return --command "$restore exec $cmd" /dev/null
    exit $?
  '';

  # `claude` for the primary user: a real executable rather than a shell
  # alias, so keybinds, `sh -c` and scripts get the sandbox too. The script
  # says where a session opens.
  enter = pkgs.replaceVarsWith {
    name = "claude";
    src = ./claude-enter.nu;
    replacements = {
      nu = pkgs.nushell;
      claudeSandbox = lib.getExe launcher;
    };
    dir = "bin";
    isExecutable = true;
  };
in {
  imports = [../../home-manager/users/claude.nix ./agent-sandbox-grants.nix];

  options.security.agentSandbox = {
    enable = lib.mkEnableOption "a dedicated unix account for Claude Code";

    # For a host nobody sits at, and only while asked for: see the
    # claude-remote-control unit below.
    remoteControl.enable = lib.mkEnableOption "an on-demand `claude remote-control` server in the sandbox account, opened with `claude-sandbox-open`";

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
      users.users.${username} = {
        extraGroups = [user];
        # Not 700: see claude-sandbox-read-acl below, which this mode keeps
        # working across switches.
        homeMode = "710";
        packages = [enter];
      };

      # Temporary read access to what stays closed otherwise. The vault and
      # this account's home are named as what it can already write. The
      # panel is sieb's pinentry, the one rbw unlocks with; a host that
      # sets `frontend = "queue"` never builds it.
      security.agentSandbox.grants = {
        enable = lib.mkDefault true;
        writablePaths = [home vaultSrc];
        pinentry = lib.mkDefault (lib.getExe inputs.sieb.packages.${pkgs.stdenv.hostPlatform.system}.pinentry);
      };

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
        "${home}/Projects" = owned;
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
      # /home/<primary> above it, so the home stays closed while the
      # vault inside is reachable. nofail: on a host where syncthing has not
      # delivered the vault yet the boot must not wait on it.
      # slave, not the default: `/` is a shared mount, so a plain bind joins
      # the source's peer group and every mount made under it propagates
      # back. The read-only `.obsidian` below then landed on the primary
      # user's own `.obsidian` too, which left Obsidian unable to save and
      # failed the ACL strip with EROFS. A slave still receives mounts from
      # the source but sends none back.
      fileSystems.${vaultDst} = {
        device = vaultSrc;
        fsType = "none";
        options = ["bind" "slave" "nofail"];
      };
      # `.obsidian` read-only in this view, on top of the ACL strip below.
      # The ACLs alone leave a gap: the agent has write on the vault root,
      # and renaming a directory within the same parent needs write on the
      # parent only, so `mv .obsidian x; mkdir .obsidian` would hand it a
      # fresh plugin directory (the root's default ACL) until the next strip.
      # A mountpoint cannot be renamed (EBUSY) and this one is not writable.
      # That holds in this mount namespace only: from a user namespace that
      # binds the source path there is no mount over `.obsidian`. The source
      # is out of reach, since ~/Documents is closed to this account
      # (claude-sandbox-close-acl).
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
        #
        # Root walks a tree the agent can write, by path. Should an entry
        # be swapped for a symlink mid-walk, the link must lead nowhere:
        # nothing but the vault is writable or even present in this unit's
        # view of /home, and the rest of the system is read-only.
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ProtectSystem = "strict";
          ProtectHome = "tmpfs";
          BindPaths = [vaultSrc];
          PrivateTmp = true;
        };
        script = ''
          vault=${lib.escapeShellArg vaultSrc}
          ${pkgs.acl}/bin/setfacl -R -m g:${user}:rwX,d:g:${user}:rwX "$vault"
          if [ -d "$vault/.obsidian" ]; then
            ${pkgs.acl}/bin/setfacl -R -x g:${user},d:g:${user} "$vault/.obsidian"
          fi
        '';
      };

      # Read-only view of the primary user's project trees, so the agent
      # sees what Martin sees without anything being copied over. Read only,
      # on purpose: whatever the agent can write inside a tree he works in
      # (.git/hooks, .envrc, build.rs, a flake) later runs as him. Writes
      # stay in its own ~/Projects, fetched from like a contributor's fork.
      #
      # The one entry added to the primary home is traverse-only (--x) for
      # this group, which lets a path through without listing the home. It
      # does not close what lies beside the trees, though. A process in a
      # group that an ACL names is judged by the group entries alone, and
      # where an inode has none it falls through to the `other` bits, which
      # umask 022 leaves at r-x. With only the traverse entry the agent read
      # ~/Documents, ~/Downloads and the shell history. So every other entry
      # directly in the home and in ~/.config carries `g:claude:---`
      # (claude-sandbox-close-acl below): a named entry that matches and
      # grants nothing ends the lookup there. One level is enough, since
      # nothing below a directory is reachable without searching it.
      #
      # The default entries make files created later in the trees readable
      # too. Hosts without one of these directories skip it.
      #
      # The home's mode is 710 for that entry's sake (homeMode above), and
      # its owning group is pinned to nothing here, tree or no tree. On a
      # directory with an ACL the mode's group bits are the mask, not the
      # owning group's rights, and userborn's tmpfiles rule chmods the home
      # to homeMode on every switch. At 700 that set the mask to --- and
      # blanked this entry until the next boot. At 710 the mask it writes
      # is --x, and `group::---` keeps `users` out all the same.
      systemd.services.claude-sandbox-read-acl = {
        description = "Grant the Claude Code sandbox user read access to the project trees";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          setfacl=${pkgs.acl}/bin/setfacl
          $setfacl -m g::--- ${lib.escapeShellArg primaryHome}
          ${lib.concatMapStringsSep "\n" (t: ''
              if [ -d ${lib.escapeShellArg t} ]; then
                $setfacl -m g:${user}:--x ${lib.escapeShellArg primaryHome}
                $setfacl -m g:${user}:--x ${lib.escapeShellArg (builtins.dirOf t)}
                $setfacl -R -m g:${user}:rX,d:g:${user}:rX ${lib.escapeShellArg t}
              fi
            '')
            sharedTrees}
        '';
      };

      # The deny entries. Not default ACLs on the two directories: those
      # replace the umask for everything created there, and are inherited
      # all the way down. Instead a pass over the direct children, at boot
      # and again whenever one of the two directories changes (the path unit
      # below), so an entry made later is closed moments after it appears.
      # A file replaced by rename is a new inode and is open for that long.
      #
      # Only entries still lacking the deny are touched. setfacl on a child
      # is an attribute change in the watched directory, so rewriting all of
      # them each time would trigger the path unit from its own service.
      # Symlinks are left alone: setfacl would follow them, into the
      # read-only store for everything home-manager links.
      systemd.services.claude-sandbox-close-acl = {
        description = "Close the primary home to the Claude Code sandbox user outside the project trees";
        wantedBy = ["multi-user.target"];
        after = ["claude-sandbox-read-acl.service"];
        serviceConfig.Type = "oneshot";
        path = [pkgs.acl pkgs.findutils pkgs.gnugrep];
        script = ''
          close() {
            dir=$1
            shift
            [ -d "$dir" ] || return 0
            find "$dir" -mindepth 1 -maxdepth 1 ! -type l "$@" -print0 |
              while IFS= read -r -d "" entry; do
                getfacl -cp -- "$entry" 2>/dev/null | grep -qx 'group:${user}:---' ||
                  setfacl -m g:${user}:--- -- "$entry" || true
              done
          }
          close ${lib.escapeShellArg primaryHome} ! -name Projects ! -name .config
          close ${lib.escapeShellArg "${primaryHome}/.config"} ! -name nixos
        '';
      };
      systemd.paths.claude-sandbox-close-acl = {
        description = "Watch the primary home for entries the sandbox user could still read";
        wantedBy = ["multi-user.target"];
        pathConfig.PathChanged = [primaryHome "${primaryHome}/.config"];
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
    # Stopping the unit also ends every session in its cgroup. A sandbox
    # shell opened over ssh during the window lives outside it and keeps the
    # GH_TOKEN it read at login until it exits.
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
          WorkingDirectory = "${home}/Projects";
          LoadCredential =
            lib.optional (config.age.secrets ? claude-github-token) "github-token:${config.age.secrets.claude-github-token.path}"
            # Only homeserver defines it: the nushell-org token for the issue
            # sweep, read as a file by its posting scripts, never exported.
            ++ lib.optional (config.age.secrets ? claude-nushell-token) "nushell-token:${config.age.secrets.claude-nushell-token.path}";
          RuntimeDirectory = "claude-sandbox";
          RuntimeDirectoryMode = "0700";
          ExecStart = lib.getExe (pkgs.writeShellScriptBin "claude-remote-control" ''
            if [ -r "''${CREDENTIALS_DIRECTORY:-/nonexistent}/github-token" ]; then
              install -m 0400 "$CREDENTIALS_DIRECTORY/github-token" "$RUNTIME_DIRECTORY/github-token"
              GH_TOKEN="$(< "$RUNTIME_DIRECTORY/github-token")"
              export GH_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"
            fi
            if [ -r "''${CREDENTIALS_DIRECTORY:-/nonexistent}/nushell-token" ]; then
              install -m 0400 "$CREDENTIALS_DIRECTORY/nushell-token" "$RUNTIME_DIRECTORY/nushell-token"
            fi
            exec ${lib.getExe' pkgs.claude-code-bin "claude"} remote-control
          '');
          # Backing off: before that first login a long window would
          # otherwise relaunch it every 30s for hours.
          Restart = "always";
          RestartSec = 30;
          RestartSteps = 5;
          RestartMaxDelaySec = "10min";
        };
      };

      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "claude-sandbox-open";
          runtimeInputs = [pkgs.systemd pkgs.gawk pkgs.coreutils];
          text = ''
            if [ "$(id -u)" -ne 0 ]; then exec /run/wrappers/bin/sudo "$0" "$@"; fi
            # C locale, so the microseconds line reads "us:" whatever the
            # caller's LANG is.
            secs() { LC_ALL=C systemd-analyze timespan "$1" | awk '$1 == "us:" { print int($2 / 1000000) }'; }
            span="''${1:-2h}"
            want=$(secs "$span" 2>/dev/null) || want=""
            if [ -z "$want" ] || [ "$want" -le 0 ]; then
              echo "claude-sandbox-open: not a time span: $span" >&2
              exit 2
            fi
            max=$(secs ${maxWindow})
            if [ "$want" -gt "$max" ]; then
              echo "claude-sandbox-open: capped at ${maxWindow}" >&2
              want=$max
            fi
            # Replace any earlier close timer, so reopening sets a fresh end;
            # a failed leftover would block reusing the transient unit's name.
            systemctl stop claude-sandbox-close.timer 2>/dev/null || true
            systemctl reset-failed claude-sandbox-close.timer claude-sandbox-close.service 2>/dev/null || true
            systemctl start claude-remote-control.service
            # An absolute path: the timer's service runs in PID 1's
            # environment, not this one.
            systemd-run --quiet --unit=claude-sandbox-close \
              --on-active="''${want}s" --timer-property=AccuracySec=1s \
              ${pkgs.systemd}/bin/systemctl stop claude-remote-control.service
            echo "Sandbox open until $(date -d "+''${want} seconds" '+%H:%M'). Close early: claude-sandbox-close"
          '';
        })
        (pkgs.writeShellApplication {
          name = "claude-sandbox-close";
          runtimeInputs = [pkgs.systemd];
          text = ''
            if [ "$(id -u)" -ne 0 ]; then exec /run/wrappers/bin/sudo "$0" "$@"; fi
            systemctl stop claude-sandbox-close.timer 2>/dev/null || true
            systemctl stop claude-remote-control.service
            echo "Sandbox closed."
          '';
        })
      ];
    })
  ];
}
