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
    overlays = [ ];
  },
}@args:
let
  inherit (inputs.nixpkgs) lib;

  getPackages = pkgs: lib.makeScope pkgs.newScope (import ./pkgs pkgs);
  getModule =
    modules:
    { pkgs, ... }:
    let
      self = import ./default.nix (args // { inherit pkgs; });
    in
    {
      imports = lib.map (module: (module self)) modules;
    };
in
{
  inherit inputs getPackages;
  packages = getPackages pkgs;
  packagesCross.aarch64-multiplatform = getPackages pkgs.pkgsCross.aarch64-multiplatform;

  nixosModules = (lib.mapAttrs (_: value: getModule [ value ]) (import ./modules/nixos)) // {
    vanilla-mobile = getModule (
      [
        (import ./modules/nixos/vanilla-mobile)
      ]
      ++ (lib.attrValues (import ./modules/nixos))
    );
  };
  homeManagerModules =
    (lib.mapAttrs (_: value: getModule [ value ]) (import ./modules/homeManager))
    // {
      vanilla-mobile = getModule (
        [
          (import ./modules/homeManager/vanilla-mobile)
        ]
        ++ (lib.attrValues (import ./modules/homeManager))
      );
    };
}
