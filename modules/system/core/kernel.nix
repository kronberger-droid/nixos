{
  pkgs,
  lib,
  ...
}: {
  # The NixOS default (6.18 LTS), stated so the choice is visible. That
  # already covers scx-schedulers.nix (sched_ext, 6.12+) and ipu6-camera.nix
  # (in-tree IPU6, 6.10+), so every host runs it. mkDefault so a host that
  # ever needs linuxPackages_latest can say so without a mkForce.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
}
