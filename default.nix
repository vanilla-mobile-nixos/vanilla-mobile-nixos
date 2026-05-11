let
  flake-inputs = import (fetchTarball {
    url = "https://github.com/fricklerhandwerk/flake-inputs/tarball/4.1.0";
    sha256 = "1j57avx2mqjnhrsgq3xl7ih8v7bdhz1kj3min6364f486ys048bm";
  });
in
{
  flake ? (flake-inputs.import-flake { src = ./.; }),
  inputs ? flake.inputs,
  system ? builtins.currentSystem,
  pkgs ? import inputs.nixpkgs {
    inherit system;
    config = {
      allowUnfreePackages = [
        "xiaomi-beryllium-firmware"
      ];
    };
    overlays = [ ];
  },
}:
let
  inherit (pkgs) lib;
in
{
  packages = lib.makeScope pkgs.newScope (import ./pkgs pkgs);
  packagesCross.aarch64-multiplatform =
    let
      pkgsCross = pkgs.pkgsCross.aarch64-multiplatform;
    in
    lib.makeScope pkgsCross.newScope (import ./pkgs pkgsCross);

  nixosModules = import ./modules/nixos flake;
  homeManagerModules = import ./modules/homeManager flake;
}
