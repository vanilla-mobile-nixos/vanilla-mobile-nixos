{
  ...
}:
{
  imports = [
    ./disko-config.nix
  ];

  # Remove this after the initial flash.
  vanilla-mobile.installer = {
    enable = true;
    # If using binfmt, set `buildSystem` to the output of:
    # `nix-instantiate --eval --expr "(import <nixpkgs> {}).stdenv.system"`
    # buildSystem =
  };

  vanilla-mobile.device.fairphone-fp5.enable = true;

  # Use the cache, so you don't have to spend hours building kernels.
  vanilla-mobile.cache.enable = true;

  # Allow using the phone's firmware.
  nixpkgs.config.allowUnfreePackages = [
    "fairphone-fp5-firmware"
  ];

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?
}
