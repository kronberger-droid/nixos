# The two colour lasers at the IAP, both Canon imageFORCE. They speak
# AirPrint, so they print driverless over IPP and need no Canon driver.
#
# The queues are declared with stored PPDs rather than `model = "everywhere"`.
# `everywhere` asks the printer for its capabilities every time the queue is
# set up, so ensure-printers.service would fail on each boot and each switch
# away from the institute. With a PPD lpadmin never contacts the printer.
#
# Each PPD is what cups-filters' `driverless` generates from its printer.
# Regenerate one on the institute network with the tunnel routed around the
# printer (the bypass below):
#
#   driverless ipp://128.130.44.211/ipp/print | save -f hosts/P14E/canon-c5140.ppd
{pkgs, ...}: let
  printers = [
    {
      # canon-dc05-e18.iap.tuwien.ac.at, the faster of the two.
      name = "iap-c5140";
      description = "Canon imageFORCE C5140";
      address = "128.130.44.211";
      ppd = ./canon-c5140.ppd;
    }
    {
      # hp-dc04-a11.iap.tuwien.ac.at
      name = "iap-c1333";
      description = "Canon imageFORCE C1333";
      address = "128.130.44.206";
      ppd = ./canon-c1333.ppd;
    }
  ];
in {
  services.printing.drivers =
    map (p: pkgs.writeTextDir "share/cups/model/${p.name}.ppd" (builtins.readFile p.ppd))
    printers;

  hardware.printers = {
    ensurePrinters =
      map (p: {
        inherit (p) name description;
        location = "IAP, TU Wien";
        deviceUri = "ipp://${p.address}/ipp/print";
        model = "${p.name}.ppd";
        ppdOptions = {
          PageSize = "A4";
          Duplex = "DuplexNoTumble";
        };
      })
      printers;
    ensureDefaultPrinter = "iap-c5140";
  };

  # The printers are in another TU subnet than the wired port, so they are
  # reached through the default route, which the tunnel takes over. TU Wien
  # drops it arriving from a Mullvad relay.
  services.mullvad-wg.bypass = map (p: "${p.address}/32") printers;
}
