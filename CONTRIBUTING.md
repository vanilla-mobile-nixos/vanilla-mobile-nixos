# Contributing to Vanilla Mobile NixOS

Contributions and questions are always welcome! Here's just a couple of things to keep
in mind:

- Remember to search the [GitHub Issues](https://github.com/vanilla-mobile-nixos/vanilla-mobile-nixos/issues) before making a bug report or feature request.
- Please [open an issue](https://github.com/vanilla-mobile-nixos/vanilla-mobile-nixos/issues/new/choose) to discuss major changes before making a pull request.

## Building kernels locally

To avoid slow builds when building on a different architecture from the kernel, make
sure to set these cross-compiling options:

```nix
vanilla-mobile.installer = {
   # Set `buildSystem` to the output of:
   # `nix-instantiate --eval --expr "(import <nixpkgs> {}).stdenv.system"`
   buildSystem = "";
   enableCrossPkgs = true;
};
```
