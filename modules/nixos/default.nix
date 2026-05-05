self: {
  vanilla-mobile = import ./vanilla-mobile self;

  bootmac = import ./bootmac.nix self;
  hexagonrpcd = import ./hexagonrpcd.nix self;
  msm-modem-uim-selection = import ./msm-modem-uim-selection.nix self;
  rmtfs = import ./rmtfs.nix;
  swclock-offset = import ./swclock-offset.nix self;
  tqftpserv = import ./tqftpserv.nix;
}
