{ config, pkgs, ... }:
{
  # Install QuickEMU
  environment.systemPackages = with pkgs; [
    quickemu
    qemu
    samba
  ];
  
  # Enable KVM for better performance
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [ pkgs.OVMFFull.fd ];
      };
    };
  };
  programs.virt-manager.enable = true;
  
  # Add your user to necessary groups
  users.users.kronberger = {
    extraGroups = [ "libvirtd" "kvm" "qemu-libvirtd" ];
  };
}
