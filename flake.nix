{
  description = "Run standard NixOS on your mobile devices!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, ... }@inputs:
    let
      getDefault =
        system:
        import ./default.nix {
          flake = self;
          inherit inputs system;
        };
    in
    (inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        default = getDefault system;
      in
      {
        packages = default.packages // {
          inherit (default) packagesCross;
        };
      }
    ))
    // (inputs.flake-utils.lib.eachDefaultSystemPassThrough (
      system:
      let
        default = getDefault system;
      in
      {
        inherit (default) nixosModules homeManagerModules;
      }
    ));
}
