{lib, ...}: {
  # P14E keyboard dock touchpad ("TPBridge", USB Elan 04f3:160a on
  # hid-multitouch).
  #
  # After a resume, niri counts one finger fewer than are on the pad: the
  # pointer needs two fingers, two-finger scroll needs three. The kernel side
  # is clean at that point (a fresh `libinput record` shows one slot per
  # finger), so the stale state lives in the compositor's long-running
  # libinput context. The USB device is not re-enumerated across s2idle,
  # which means nothing ever tells that context to start over.
  #
  # Rebinding the multitouch interface removes and re-adds the input nodes,
  # so niri drops the device and builds a fresh libinput one. Only the
  # multitouch HID interface is rebound; the keyboard sits on a separate
  # hid-generic interface and is left alone. Matched on vendor/product
  # because the HID instance number (.0002) is assigned at probe time.
  powerManagement.resumeCommands = lib.mkAfter ''
    drv=/sys/bus/hid/drivers/hid-multitouch
    for dev in "$drv"/0003:04F3:160A.*; do
      [ -e "$dev" ] || continue
      id=''${dev##*/}
      echo "$id" > "$drv/unbind" || true
      echo "$id" > "$drv/bind" || true
    done
  '';
}
