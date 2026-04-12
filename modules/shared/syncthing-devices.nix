# Shared syncthing device definitions used by both system and Home Manager modules.
# Get device IDs with: syncthing -device-id (or from the web UI)
{
  devices = {
    homeserver = {
      id = "TFHHQZC-OZCHJDU-SVETB4J-2LNTROX-FYJZFT5-BG2LG2X-CIRCEEZ-LLRVFAR";
      addresses = ["tcp://192.168.2.54:22000" "tcp://100.92.46.97:22000" "dynamic"];
    };
    spectre = {
      id = "4RZB52C-SF37CKE-IUGTFM4-HZYF76P-55RKI4G-NYAE5SZ-GVRW2DP-SGSWJAK";
      addresses = ["tcp://100.83.89.128:22000" "dynamic"];
    };
    intelNuc = {
      id = "UKYT4BM-RHAHSKP-3EW3QRN-USWUMRL-MC56REB-AM4JDPZ-GLY3QW5-XRKW4QI";
      addresses = ["tcp://100.64.13.9:22000" "dynamic"];
    };
  };

  mobileDevices = {
    nothing-phone = {
      id = "EIB56A6-BLR43CP-N6243GG-NNI6S3B-OFVE2NO-BA3QYZW-YPG5CUD-CEJTXA7";
      addresses = ["dynamic"];
    };
  };
}
