{
  pkgs,
  lib,
  ...
}: {
  # The NixOS default, stated so the choice is visible. mkDefault so a host
  # that needs linuxPackages_latest (scx-schedulers.nix wants 6.12+,
  # ipu6-camera.nix 6.16+) can say so without a mkForce.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages;
}
