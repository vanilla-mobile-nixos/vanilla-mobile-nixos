self: {
  bootmac = import ./bootmac.nix self;
  swclock-offset = import ./swclock-offset.nix self;
}
