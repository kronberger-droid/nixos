# Auto-attach to a persistent zellij session on interactive SSH logins.
#
# Curried on the session name, so each host picks its own:
#   imports = [(import ./zellij-ssh-autostart.nix {session = "main";})];
#
# Deliberately not programs.zellij.enable*Integration: those inject an
# *ungated* autostart into the shell rc, which would wrap every SSH
# invocation — including non-interactive ones (`ssh host 'cmd'`, scp,
# nixos-rebuild --build-host/--target-host, deploy-rs). We autostart from
# nushell with an explicit guard instead. (There is no nushell integration
# in the HM module anyway.)
#
# Both halves of the guard are load-bearing:
#   - SSH_TTY is only set when sshd allocated a PTY, i.e. a real interactive
#     login, so command-mode SSH traffic never matches.
#   - ZELLIJ stops the inner pane shell — which re-sources config.nu — from
#     recursively re-attaching.
#
# mkAfter so it runs at the very end of config.nu, once the shell is set up.
{session}: {lib, ...}: {
  programs.nushell.extraConfig = lib.mkAfter ''

    if ('SSH_TTY' in $env) and ('ZELLIJ' not-in $env) {
        zellij attach --create ${session}
    }
  '';
}
