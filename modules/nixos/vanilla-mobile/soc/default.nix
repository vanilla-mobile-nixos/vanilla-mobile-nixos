self: {
  imports = [
    (import ./sc7280 self)
    (import ./sdm845 self)
    ./qualcomm.nix
  ];
}
