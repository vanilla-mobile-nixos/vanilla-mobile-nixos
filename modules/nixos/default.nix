{
  bootmac = import ./bootmac.nix;
  hexagonrpcd = import ./hexagonrpcd.nix;
  msm-modem-uim-selection = import ./msm-modem-uim-selection.nix;
  rmtfs = import ./rmtfs.nix;
  swclock-offset = import ./swclock-offset.nix;
  tqftpserv = import ./tqftpserv.nix;
  usb-gadget = import ./usb-gadget.nix;
  usb-moded = import ./usb-moded.nix;
  q6voiced = import ./q6voiced.nix;
}
