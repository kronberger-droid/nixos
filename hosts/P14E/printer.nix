# The colour laser at the IAP, a Canon imageFORCE C1333
# (hp-dc04-a11.iap.tuwien.ac.at). It speaks AirPrint, so it prints driverless
# over IPP and needs no Canon driver.
#
# The queue is declared with a stored PPD rather than `model = "everywhere"`.
# `everywhere` asks the printer for its capabilities every time the queue is
# set up, so ensure-printers.service would fail on each boot and each switch
# away from the institute. With a PPD lpadmin never contacts the printer.
#
# canon-c1333.ppd is what cups-filters' `driverless` generates from the
# printer. Regenerate it on the institute network with the tunnel routed
# around the printer (the bypass below):
#
#   driverless ipp://128.130.44.206/ipp/print | save -f hosts/P14E/canon-c1333.ppd
{pkgs, ...}: let
  address = "128.130.44.206";
in {
  services.printing.drivers = [
    (pkgs.writeTextDir "share/cups/model/canon-c1333.ppd" (builtins.readFile ./canon-c1333.ppd))
  ];

  hardware.printers = {
    ensurePrinters = [
      {
        name = "iap-canon";
        description = "Canon imageFORCE C1333";
        location = "IAP, TU Wien";
        deviceUri = "ipp://${address}/ipp/print";
        model = "canon-c1333.ppd";
        ppdOptions = {
          PageSize = "A4";
          Duplex = "DuplexNoTumble";
        };
      }
    ];
    ensureDefaultPrinter = "iap-canon";
  };

  # The printer is in another TU subnet than the wired port, so it is reached
  # through the default route, which the tunnel takes over. TU Wien drops it
  # arriving from a Mullvad relay.
  services.mullvad-wg.bypass = ["${address}/32"];
}
