# Shared syncthing device definitions used by both system and Home Manager modules.
# Get device IDs with: syncthing -device-id (or from the web UI)
# Tailnet addresses only: see syncthing-options.nix for why there is no
# "dynamic" and no LAN address.
let
  homeserver = import ./homeserver.nix;
in {
  devices = {
    homeserver = {
      id = "TFHHQZC-OZCHJDU-SVETB4J-2LNTROX-FYJZFT5-BG2LG2X-CIRCEEZ-LLRVFAR";
      addresses = ["tcp://${homeserver.tailnet4}:22000"];
    };
    spectre = {
      id = "TYV4VO6-CXEJIBC-VSC5V6K-BKC2MZS-B6UI74J-VVTG7KH-SN65JSX-TNBDWAQ";
      addresses = ["tcp://100.116.232.46:22000"];
    };
    intelNuc = {
      id = "UKYT4BM-RHAHSKP-3EW3QRN-USWUMRL-MC56REB-AM4JDPZ-GLY3QW5-XRKW4QI";
      addresses = ["tcp://100.64.13.9:22000"];
    };
    P14E = {
      id = "A7PN6IC-IJE2WVL-4CM3BR5-SK7JDKV-NZSBPU7-NPKXZ5R-UMYEAVU-IOUBYQM";
      addresses = ["tcp://100.103.204.24:22000"];
    };
  };

  mobileDevices = {
    nothing-phone = {
      id = "EIB56A6-BLR43CP-N6243GG-NNI6S3B-OFVE2NO-BA3QYZW-YPG5CUD-CEJTXA7";
      addresses = ["tcp://100.120.115.46:22000"];
    };
  };
}
