# Temporary, approved access for the sandbox account to data it cannot
# read: something of root's, or something in the primary user's home.
#
# A grant is a read-only bind mount of the source under
# /run/claude-sandbox-grants, with an id map that turns the source's owner
# into the sandbox account for that one mount, and a transient timer that
# takes it away again. No ACL and no group membership changes anywhere, so
# nothing is left behind on the source, and a reboot ends every grant
# because /run is a tmpfs. Data that is no file (the journal) is copied
# into the same directory by a declared command and deleted by the same
# kind of timer.
#
# The pieces, in the order a request passes them:
#   claude-sandbox-request   the sandbox's CLI: path, span, reason, written
#                            to a unix socket.
#   the broker               one process per request, as the primary user.
#                            Resolves the path, applies the rate limits and
#                            asks. `prompt`: a sieb-pinentry panel in his
#                            session, where the approval is his password,
#                            checked by sudo. `queue`: the request waits for
#                            `claude-sandbox-grant approve`, for a host with
#                            no compositor. A prompt host falls back to the
#                            queue when it has no Wayland display.
#   the helper               root, behind sudo. Checks everything again,
#                            mounts, schedules the end.
#
# What a grant is, and is not. While it is open the agent can copy the
# whole tree into its own home, so approving one means "it may have all of
# this". The span bounds how long it sees changes, nothing else.
#
# Why the approval is a password on the workstations. The primary user
# runs anything as the sandbox account without one (`claude-sandbox`). A
# passwordless helper would therefore let every process of his read
# whatever the helper agrees to mount, root's files included. The one
# passwordless way in is the auto-approve list below, enforced by the
# helper itself.
#
# GRANTS_DIR belongs to root, group claude, 0750. Not to the sandbox
# account: root creates mountpoints in it, and in a directory the agent
# owned it could swap a fresh mountpoint for a symlink before the mount
# landed on it. The primary user is in that group and gains nothing by it,
# since inside a grant his own files appear as the sandbox's.
#
# tests/sandbox-grants.nix runs the whole path in a VM, both frontends.
{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.security.agentSandbox.grants;
  user = "claude";
  primary = config.users.users.${username};

  grantsDir = "/run/claude-sandbox-grants";
  stateDir = "/run/claude-sandbox-grant-state";
  brokerDir = "/run/claude-sandbox-broker";
  socket = "${brokerDir}/sock";
  brokerState = "${brokerDir}/state";
  sudo = "/run/wrappers/bin/sudo";

  # Never granted, whatever the lists below say. In the home: keys,
  # tokens, password stores and browser profiles. A request for a
  # directory above one of these is refused too, so ~/.config as a whole
  # is out and ~/.config/niri is fine.
  homeDeny = map (p: "${primary.home}/${p}") [
    ".ssh"
    ".gnupg"
    ".password-store"
    ".netrc"
    ".aws"
    ".kube"
    ".docker"
    ".mozilla"
    ".zen"
    ".librewolf"
    ".thunderbird"
    ".config/gh"
    ".config/nix"
    ".config/rbw"
    ".config/sops"
    ".config/age"
    ".config/rclone"
    ".config/syncthing"
    ".config/chromium"
    ".config/BraveSoftware"
    ".config/google-chrome"
    ".local/share/rbw"
    ".local/share/keyrings"
    ".local/state/syncthing"
    ".cache/rbw"
  ];
  systemDeny = [
    "/etc/shadow"
    "/etc/ssh"
    "/etc/NetworkManager/system-connections"
    "/root"
    "/run/agenix"
    "/run/agenix.d"
    "/run/secrets"
    "/run/credentials"
    "/var/lib/tailscale"
    "/var/lib/systemd"
  ];

  # Each script is its file with the settings it reads in front, built by
  # writeShellApplication so shellcheck sees the two together. A script
  # gets only the names it uses: an unused one fails that check.
  script = name: runtimeInputs: vars: extra: file:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = lib.toShellVars vars + "\n" + extra + builtins.readFile file;
    };

  # The declared snapshot sources as one shell function, so the helper
  # runs argv arrays written here and never a string from a request.
  snapshotSource = ''
    snapshot_source() {
      case "$1" in
    ${lib.concatStrings (lib.mapAttrsToList (name: s: ''
        ${lib.escapeShellArg name})
          snap_cmd=(${lib.escapeShellArgs s.command})
          snap_pattern=${lib.escapeShellArg (lib.optionalString (s.argPattern != null) s.argPattern)}
          snap_auto=${lib.escapeShellArg (lib.optionalString s.auto "1")}
          ;;
      '')
      cfg.snapshots)}
        *) return 1 ;;
      esac
    }
  '';

  helper =
    script "claude-sandbox-grant-helper"
    (with pkgs; [coreutils util-linux systemd gawk findutils gnused])
    {
      SANDBOX_USER = user;
      PRIMARY_USER = username;
      PRIMARY_HOME = primary.home;
      GRANTS_DIR = grantsDir;
      STATE_DIR = stateDir;
      MAX_SPAN = cfg.maxSpan;
      MAX_GRANTS = cfg.maxGrants;
      SNAPSHOT_MAX_BYTES = cfg.snapshotMaxBytes;
      DENY = homeDeny ++ systemDeny ++ cfg.extraDenyPaths;
      SYSTEM_PATHS = cfg.systemPaths;
      WRITABLE = cfg.writablePaths;
      AUTO_PATHS = cfg.autoApprove;
    }
    snapshotSource
    ./sandbox-grants/helper.sh;
  helperBin = lib.getExe helper;

  # What the passwordless sudo rule names. Always --auto, which holds the
  # helper to the auto-approve list.
  auto = pkgs.writeShellScriptBin "claude-sandbox-grant-auto" ''
    exec ${helperBin} --auto "$@"
  '';

  askpass =
    script "claude-sandbox-grant-askpass" [pkgs.coreutils] {
      STATE = brokerState;
      PROMPT_TIMEOUT = cfg.promptTimeout;
      PINENTRY = cfg.pinentry;
    } ""
    ./sandbox-grants/askpass.sh;

  broker =
    script "claude-sandbox-broker" (with pkgs; [coreutils util-linux]) {
      SANDBOX_USER = user;
      DEFAULT_SPAN = cfg.defaultSpan;
      STATE = brokerState;
      LOCKOUT_DENIALS = cfg.lockoutDenials;
      COOLDOWN = cfg.cooldown;
      PATH_COOLDOWN = cfg.pathCooldown;
      QUEUE_TIMEOUT = cfg.queueTimeout;
      HELPER = helperBin;
      SUDO = sudo;
      AUTO = lib.getExe auto;
      ASKPASS = lib.optionalString (cfg.frontend == "prompt" && cfg.pinentry != null) (lib.getExe askpass);
    } ""
    ./sandbox-grants/broker.sh;

  request =
    script "claude-sandbox-request" (with pkgs; [coreutils socat]) {
      GRANTS_DIR = grantsDir;
      DEFAULT_SPAN = cfg.defaultSpan;
      MAX_SPAN = cfg.maxSpan;
      QUEUE_TIMEOUT = cfg.queueTimeout;
      SOCKET = socket;
    } ""
    ./sandbox-grants/request.sh;

  grant =
    script "claude-sandbox-grant" [pkgs.coreutils] {
      PRIMARY_USER = username;
      STATE = brokerState;
      HELPER = helperBin;
      SUDO = sudo;
    } ""
    ./sandbox-grants/grant.sh;

  # Accept=yes: one broker process per connection, with the connection as
  # its stdin and stdout, so the broker is a script that reads three lines.
  # The socket is the primary user's, open to the sandbox's group.
  socketConfig = {
    ListenStream = socket;
    Accept = true;
    SocketMode = "0660";
    SocketGroup = user;
    MaxConnections = 4;
  };
  serviceConfig = {
    ExecStart = "${lib.getExe broker} %i";
    StandardInput = "socket";
    StandardOutput = "socket";
    # Else stderr follows stdout onto the socket, and sudo's complaints
    # land in the agent's answer.
    StandardError = "journal";
  };
in {
  options.security.agentSandbox.grants = {
    enable = lib.mkEnableOption "temporary, approved read access for the sandbox account";

    frontend = lib.mkOption {
      type = lib.types.enum ["prompt" "queue"];
      default = "prompt";
      description = ''
        How a request gets its answer. `prompt` runs the broker in the
        primary user's own systemd instance and asks in a sieb-pinentry
        panel. `queue` runs it as a system unit and waits for
        `claude-sandbox-grant approve`, for a host with no compositor.
      '';
    };

    pinentry = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "The pinentry program the prompt runs. Without one every request is queued.";
    };

    defaultSpan = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      description = "How long a grant lasts when the request does not say.";
    };
    maxSpan = lib.mkOption {
      type = lib.types.str;
      default = "4h";
      description = "The longest a grant lasts, whatever was asked for.";
    };
    maxGrants = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "How many grants may be open at once.";
    };
    snapshotMaxBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32 * 1024 * 1024;
      description = "Where a snapshot is cut off. They live in /run, which is memory.";
    };

    systemPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = ["/var/log"];
      description = ''
        Where data that is not the primary user's may be granted from: the
        only paths owned by root or a service account the helper mounts.
        Each grant still needs its approval.
      '';
    };
    extraDenyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "Paths never granted, on top of the built-in list of keys, tokens and browser profiles.";
    };
    writablePaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = ''
        Trees the sandbox account can write. Never granted: it has them
        already, and a source it can rearrange while the helper looks at
        it is the one place a symlink race could start.
      '';
    };
    autoApprove = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      example = ["/var/log/nginx"];
      description = ''
        Paths granted without asking, they and everything below them. The
        zones and the deny list still apply.
      '';
    };

    snapshots = lib.mkOption {
      default = {};
      description = ''
        Named sources of data that is no file, asked for as
        `@name` or `@name:arg`. The helper runs the command as root and
        hands the sandbox a copy of its output.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "The argv to run, with absolute paths. The argument, when there is one, is appended.";
          };
          argPattern = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "An extended regex the whole argument must match. null: the source takes none.";
          };
          auto = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Granted without asking.";
          };
        };
      });
    };

    promptTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = "Seconds the panel stays up unanswered.";
    };
    queueTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 600;
      description = "Seconds a queued request waits for its answer.";
    };
    cooldown = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 60;
      description = "Seconds after a denial in which nothing may be asked.";
    };
    pathCooldown = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 300;
      description = "Seconds after a denial in which the same thing may not be asked again.";
    };
    lockoutDenials = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Denials within an hour that lock requests until `claude-sandbox-grant reset`.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.all (n: builtins.match "[a-z0-9-]+" n != null) (lib.attrNames cfg.snapshots);
          message = "security.agentSandbox.grants.snapshots: names are lower-case letters, digits and dashes";
        }
      ];

      # The journal is the reason snapshots exist: reading it otherwise
      # takes the systemd-journal group, which is for good. Per unit, or
      # the whole boot.
      security.agentSandbox.grants.snapshots = {
        journal = {
          command = lib.mkDefault ["${pkgs.systemd}/bin/journalctl" "--no-pager" "-o" "short-iso" "-b" "-u"];
          argPattern = lib.mkDefault "[A-Za-z0-9][A-Za-z0-9@:_.-]*";
        };
        journal-boot.command = lib.mkDefault ["${pkgs.systemd}/bin/journalctl" "--no-pager" "-o" "short-iso" "-b"];
      };

      environment.systemPackages = [request grant];

      # The state directory lists what is open and is world-readable on
      # purpose: `claude-sandbox-grant list` needs no root, and the agent
      # may know what it holds. The broker's own state is the primary
      # user's alone.
      systemd.tmpfiles.settings."10-claude-sandbox-grants" = {
        ${grantsDir}.d = {
          mode = "0750";
          user = "root";
          group = user;
        };
        ${stateDir}.d = {
          mode = "0755";
          user = "root";
          group = "root";
        };
        ${brokerDir}.d = {
          mode = "0750";
          user = username;
          group = user;
        };
        ${brokerState}.d = {
          mode = "0700";
          user = username;
          inherit (primary) group;
        };
      };

      security.sudo-rs.extraRules = [
        {
          users = [username];
          commands = [
            {
              command = lib.getExe auto;
              options = ["NOPASSWD"];
            }
          ];
        }
      ];
    }

    # In his own systemd instance, where the session's WAYLAND_DISPLAY is.
    # These are units for every user's instance, so the condition keeps
    # the sandbox account's own from trying to bind the socket.
    (lib.mkIf (cfg.frontend == "prompt") {
      systemd.user.sockets.claude-sandbox-broker = {
        description = "Requests for sandbox grants";
        wantedBy = ["sockets.target"];
        unitConfig.ConditionUser = username;
        inherit socketConfig;
      };
      systemd.user.services."claude-sandbox-broker@" = {
        description = "Sandbox grant request";
        unitConfig.ConditionUser = username;
        inherit serviceConfig;
      };
    })

    # A system unit under his uid: nobody is logged in on such a host, so
    # there is no instance of his to carry it.
    (lib.mkIf (cfg.frontend == "queue") {
      systemd.sockets.claude-sandbox-broker = {
        description = "Requests for sandbox grants";
        wantedBy = ["sockets.target"];
        socketConfig = socketConfig // {SocketUser = username;};
      };
      systemd.services."claude-sandbox-broker@" = {
        description = "Sandbox grant request";
        serviceConfig = serviceConfig // {User = username;};
      };
    })
  ]);
}
