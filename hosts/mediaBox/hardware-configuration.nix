# PLACEHOLDER — this file MUST be regenerated on the actual notebook before
# the host will build. On the target machine (after partitioning/mounting), run:
#
#   nixos-generate-config --root /mnt --show-hardware-config \
#     > hosts/mediaBox/hardware-configuration.nix
#
# (or `nixos-generate-config --show-hardware-config` on an already-running
# system). It writes the real filesystems, boot device, and kernel modules.
#
# The throw below is a guard so this stub can never be silently deployed with
# fake hardware — replace the whole file, then delete this comment block.
{...}:
throw "hosts/mediaBox/hardware-configuration.nix is a placeholder — generate the real one on the target machine with `nixos-generate-config --show-hardware-config`."
