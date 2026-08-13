self: {
  imports = [
    (import ./sdm845 self)
    (import ./qcm6490 self)
  ];
}
