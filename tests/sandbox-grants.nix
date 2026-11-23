# security/agent-sandbox-grants.nix end to end, in a VM: a request from the
# sandbox account, the answer, the id-mapped mount on ext4, its end, and
# what is refused on the way. Two machines, one per frontend. `desk` asks
# for the primary user's password through a stand-in pinentry; `server`
# queues the request for `claude-sandbox-grant approve`.
#
# Only the grants module is imported, with two bare accounts in place of
# the whole sandbox setup, so the test builds no home-manager profile.
{pkgs}: let
  # Speaks as much Assuan as the askpass script needs. What it "types" is
  # the content of /tmp/pin-answer, or a cancel when that says so. The
  # description it was given is left in /tmp/pin-desc for the test to read.
  pinentry = pkgs.writeShellScript "test-pinentry" ''
    echo "OK Pleased to meet you"
    while read -r cmd rest; do
      case $cmd in
        SETDESC)
          echo "$rest" > /tmp/pin-desc
          echo OK
          ;;
        GETPIN)
          answer=$(cat /tmp/pin-answer)
          if [ "$answer" = cancel ]; then
            echo "ERR 83886179 Operation cancelled <Pinentry>"
          else
            echo "D $answer"
            echo OK
          fi
          ;;
        BYE)
          echo "OK closing connection"
          exit 0
          ;;
        *) echo OK ;;
      esac
    done
  '';

  common = {pkgs, ...}: {
    imports = [../modules/system/security/agent-sandbox-grants.nix];

    users.groups.claude = {};
    users.users.claude = {
      isNormalUser = true;
      uid = 1001;
      group = "claude";
    };
    users.users.kronberger = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = ["claude" "wheel"];
      password = "hunter2";
    };

    # As on the real hosts: sudo-rs with hardening.nix's defaults.
    security.sudo.enable = false;
    security.sudo-rs = {
      enable = true;
      extraConfig = ''
        Defaults timestamp_timeout=5
        Defaults passwd_timeout=1
        Defaults use_pty
      '';
    };

    security.agentSandbox.grants = {
      enable = true;
      writablePaths = ["/home/claude"];
      autoApprove = ["/var/log/auto"];
      # No waiting between the denials the test hands out, and a lockout
      # after two of them.
      cooldown = 0;
      lockoutDenials = 2;
    };

    environment.systemPackages = [pkgs.acl];
  };
in
  pkgs.testers.runNixOSTest {
    name = "sandbox-grants";
    node.specialArgs.username = "kronberger";

    nodes.server = {
      imports = [common];
      security.agentSandbox.grants.frontend = "queue";
      # The homeserver's rule: no password for the primary user.
      security.sudo-rs.extraRules = [
        {
          users = ["kronberger"];
          commands = [
            {
              command = "ALL";
              options = ["NOPASSWD"];
            }
          ];
        }
      ];
    };

    nodes.desk = {
      imports = [common];
      security.agentSandbox.grants = {
        frontend = "prompt";
        inherit pinentry;
      };
    };

    testScript = ''
      import shlex

      STATE = "/run/claude-sandbox-broker/state"

      def claude(cmd):
          return "runuser -u claude -- sh -c " + shlex.quote(cmd)

      def primary(cmd):
          return "runuser -u kronberger -- sh -c " + shlex.quote(cmd)

      def request(machine, target, span="10m", reason="for the test"):
          """Ask and wait for the answer: (exit status, last line)."""
          status, out = machine.execute(claude(f"claude-sandbox-request {target} {span} {reason}"))
          return status, out.strip().splitlines()[-1]

      def granted(machine, target, span="10m"):
          status, last = request(machine, target, span)
          assert status == 0 and last.startswith("granted "), last
          return last.split()[1]

      def refused(machine, target, word="refused"):
          status, last = request(machine, target)
          assert status != 0 and last.startswith(word), last
          return last

      def ask(machine, target, span="10m"):
          """Ask in the background, for a request that will sit in the queue."""
          machine.succeed("rm -f /tmp/answer")
          machine.succeed(claude(f"claude-sandbox-request {target} {span} for the test") + " >/tmp/answer 2>&1 &")
          machine.wait_until_succeeds(f"test -f {STATE}/pending")
          return machine.succeed(f"head -n 1 {STATE}/pending").strip()

      def answer(machine, verb, rid):
          machine.succeed(primary(f"claude-sandbox-grant {verb} {rid}"))
          machine.wait_until_succeeds("grep -Eq '^(granted|refused|denied)' /tmp/answer")
          return machine.succeed("tail -n 1 /tmp/answer").strip()

      def approved(machine, target, span="10m"):
          last = answer(machine, "approve", ask(machine, target, span))
          assert last.startswith("granted "), last
          return last.split()[1]

      def helper(machine):
          return machine.succeed(
              "grep -o '/nix/store/[^ \"]*/bin/claude-sandbox-grant-helper'"
              " $(readlink -f $(command -v claude-sandbox-grant)) | head -n 1"
          ).strip()

      def populate(machine):
          machine.succeed(
              "install -d -o kronberger -g users -m 700 /home/kronberger/Documents /home/kronberger/.ssh",
              "echo NOTE > /home/kronberger/Documents/note",
              "echo KEY > /home/kronberger/.ssh/id_ed25519",
              "chown kronberger:users /home/kronberger/Documents/note /home/kronberger/.ssh/id_ed25519",
              "chmod 600 /home/kronberger/Documents/note /home/kronberger/.ssh/id_ed25519",
              "echo ROOTS > /home/kronberger/Documents/roots && chmod 600 /home/kronberger/Documents/roots",
              "ln -s /etc /home/kronberger/Documents/etc-link",
              "echo SECRET > /var/log/secret.log && chmod 600 /var/log/secret.log",
              "mkdir -p /var/log/auto && echo AUTO > /var/log/auto/log && chmod 600 /var/log/auto/log",
              # The deny entry claude-sandbox-close-acl puts on everything in
              # the real home. A grant has to read past it.
              "setfacl -m g:claude:--- /home/kronberger/Documents",
          )

      start_all()

      # ---------------------------------------------------------------- server
      server.wait_for_unit("multi-user.target")
      server.wait_for_unit("claude-sandbox-broker.socket")
      populate(server)
      # Everything below is about ext4, where the real homes are.
      assert server.succeed("findmnt -no FSTYPE -T /home/kronberger").strip() == "ext4"
      server.fail(claude("cat /home/kronberger/Documents/note"))

      with subtest("a queued request is granted as an id-mapped read-only mount"):
          path = approved(server, "/home/kronberger/Documents")
          assert path.startswith("/run/claude-sandbox-grants/Documents-"), path
          assert server.succeed(claude(f"cat {path}/note")).strip() == "NOTE"
          assert server.succeed(claude(f"stat -c %U {path}/note")).strip() == "claude"
          options = server.succeed(f"findmnt -no OPTIONS,PROPAGATION {path}")
          for word in ["ro", "nosuid", "nodev", "noexec", "idmapped", "private"]:
              assert word in options, options
          server.fail(claude(f"touch {path}/new"))
          server.fail(claude(f"sh -c 'echo x >> {path}/note'"))
          # One owner is mapped. Root's file in the same tree is not his.
          server.fail(claude(f"cat {path}/roots"))
          # The source is as closed as before, and so is the rest of the home.
          server.fail(claude("cat /home/kronberger/Documents/note"))
          server.fail(claude("cat /home/kronberger/.ssh/id_ed25519"))
          assert "Documents-" in server.succeed(primary("claude-sandbox-grant list"))

      with subtest("revoking ends a grant that is still in use"):
          name = path.rsplit("/", 1)[1]
          server.succeed(claude(f"cd {path} && exec sleep 600") + " >/dev/null 2>&1 &")
          server.wait_until_succeeds("pgrep -u claude sleep")
          server.succeed(primary(f"claude-sandbox-grant revoke {name}"))
          server.fail(f"test -e {path}")
          server.fail("pgrep -u claude sleep")
          server.fail(f"findmnt {path}")
          assert name not in server.succeed(primary("claude-sandbox-grant list"))

      with subtest("the timer ends a grant"):
          path = approved(server, "/home/kronberger/Documents", "5s")
          server.succeed(claude(f"cat {path}/note"))
          server.wait_until_fails(f"test -e {path}", timeout=60)

      with subtest("a single file of root's, from a declared system path"):
          path = approved(server, "/var/log/secret.log")
          assert server.succeed(claude(f"cat {path}")).strip() == "SECRET"
          server.fail(claude("cat /var/log/secret.log"))

      with subtest("the auto-approve list needs no answer"):
          path = granted(server, "/var/log/auto")
          assert server.succeed(claude(f"cat {path}/log")).strip() == "AUTO"

      with subtest("a snapshot is a copy of a declared command's output"):
          path = approved(server, "@journal-boot")
          server.succeed(claude(f"test -s {path}"))
          assert server.succeed(f"stat -c '%U %a' {path}").strip() == "claude 400"
          refused(server, "'@journal:x.service;id'")
          refused(server, "@shell:id")

      with subtest("what is never granted is refused before anyone is asked"):
          for target in [
              "/home/kronberger/.ssh",
              "/home/kronberger/.ssh/id_ed25519",
              "/home/kronberger",
              "/home/claude",
              "/etc/shadow",
              "/etc/passwd",
              "/run/user",
              "/",
          ]:
              refused(server, target)
          # Resolved by the broker: the link is /etc, which is no zone.
          assert "/etc" in refused(server, "/home/kronberger/Documents/etc-link")
          server.fail(f"test -e {STATE}/pending")

      with subtest("the helper checks for itself"):
          h = helper(server)
          for args in [
              "grant /etc/shadow 10m",
              "grant /home/kronberger/.ssh 10m",
              "grant /home/kronberger/Documents/etc-link 10m",
              "grant /home/kronberger/Documents/roots 10m",
              "grant /home/kronberger/Documents/../.ssh 10m",
              "--auto grant /home/kronberger/Documents 10m",
              "snapshot journal '-x' 10m",
          ]:
              status, out = server.execute(f"{h} {args}")
              assert status == 3 and out.startswith("refused"), f"{args}: {status} {out}"
          # And is root's alone.
          server.fail(claude(f"{h} grant /home/kronberger/Documents 10m"))
          server.fail(claude(f"{h} revoke x"))

      with subtest("only the sandbox account asks"):
          out = server.succeed(primary("claude-sandbox-request /home/kronberger/Documents 10m x || true"))
          assert "only the sandbox account" in out, out

      with subtest("denials cool down, then lock"):
          last = answer(server, "deny", ask(server, "/home/kronberger/Documents"))
          assert last == "denied", last
          # The same thing again, straight away: refused without a prompt.
          assert "was denied" in refused(server, "/home/kronberger/Documents")
          last = answer(server, "deny", ask(server, "/var/log/secret.log"))
          assert last == "denied", last
          refused(server, "/var/log/secret.log", "locked")
          server.succeed(primary("claude-sandbox-grant reset"))
          approved(server, "/home/kronberger/Documents")

      with subtest("the number of open grants is capped"):
          # Eight is the default; some are open already.
          for _ in range(8):
              status, last = request(server, "/var/log/auto")
              if status != 0:
                  break
          assert "grants are open already" in last, last

      # ------------------------------------------------------------------ desk
      desk.wait_for_unit("multi-user.target")
      populate(desk)
      desk.succeed("loginctl enable-linger kronberger")
      desk.wait_for_unit("user@1000.service")
      desk.wait_until_succeeds("test -S /run/claude-sandbox-broker/sock")
      # What niri's session start does for the real one.
      desk.succeed("systemctl --user -M kronberger@ set-environment WAYLAND_DISPLAY=wayland-test")

      with subtest("the password in the panel grants"):
          desk.succeed("echo hunter2 > /tmp/pin-answer")
          path = granted(desk, "/home/kronberger/Documents")
          assert desk.succeed(claude(f"cat {path}/note")).strip() == "NOTE"
          # The panel showed the path the broker resolved.
          assert "/home/kronberger/Documents for 10m" in desk.succeed("cat /tmp/pin-desc")

      with subtest("a wrong password does not"):
          desk.succeed("echo nope > /tmp/pin-answer")
          refused(desk, "/var/log/secret.log", "denied: no answer")

      with subtest("Escape is a denial"):
          desk.succeed("echo cancel > /tmp/pin-answer")
          status, last = request(desk, "/var/log/secret.log")
          assert status != 0 and last == "denied", last

      with subtest("there is no passwordless way to the helper"):
          h = helper(desk)
          desk.fail(primary(f"sudo -n {h} grant /home/kronberger/Documents 10m"))
          # The one rule without a password is held to the auto list.
          auto = desk.succeed("grep -o '/nix/store/[^ ]*claude-sandbox-grant-auto' /etc/sudoers | head -n 1").strip()
          status, out = desk.execute(primary(f"sudo -n {auto} grant /home/kronberger/Documents 10m"))
          assert status == 3 and "auto-approve" in out, f"{status} {out}"
          desk.succeed(primary(f"sudo -n {auto} grant /var/log/auto 10m"))

      with subtest("without a display the request is queued"):
          desk.succeed("systemctl --user -M kronberger@ unset-environment WAYLAND_DISPLAY")
          rid = ask(desk, "/home/kronberger/Documents")
          last = answer(desk, "deny", rid)
          assert last == "denied", last
    '';
  }
