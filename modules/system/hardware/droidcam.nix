{
  pkgs,
  config,
  ...
}: {
  boot = {
    kernelModules = ["v4l2loopback"];
    extraModulePackages = [
      (config.boot.kernelPackages.v4l2loopback.overrideAttrs (old: {
        # nixpkgs now keeps System.map in kernel.dev, which makes Kbuild's
        # modules_install run depmod into $out and collide with the kernel's
        # own index files in aggregateModules.
        makeFlags = old.makeFlags ++ ["DEPMOD=true"];
      }))
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=42 card_label="DroidCam" exclusive_caps=1
    '';
  };

  environment.systemPackages = with pkgs; [
    droidcam
    android-tools
  ];
}
