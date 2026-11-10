self: {
  imports = [
    (import ./sdm845 self)
    (import ./sm8250 self)
    ./qualcomm.nix
  ];
}
