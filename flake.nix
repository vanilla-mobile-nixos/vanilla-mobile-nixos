{
  description = "Run standard NixOS on your mobile devices!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, flake-utils, ... }@inputs:
    let
      getDefault =
        system:
        import ./default.nix {
          flake = self;
          inherit inputs system;
        };
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        default = getDefault system;
      in
      {
        packages = flake-utils.lib.flattenTree default.packages;
      }
    ))
    // (flake-utils.lib.eachDefaultSystemPassThrough (
      system:
      let
        default = getDefault system;
      in
      {
        inherit (default) nixosModules homeManagerModules;
      }
    ));
}
