{
  lib,
  config,
  ...
}:
let
  cfg = config.vanilla-mobile.cache;
in
{
  options.vanilla-mobile.cache = {
    enable = lib.mkEnableOption "binary cache for vanilla-mobile-nixos packages";
  };

  config = lib.mkIf cfg.enable {
    # Enable in module, so the cache or cache signing key can be later changed
    # without breaking configs.
    nix.settings = {
      substituters = [
        "https://vanilla-mobile-nixos.cachix.org"
      ];
      trusted-public-keys = [
        "vanilla-mobile-nixos.cachix.org-1:nicMQxxTD4n6PM9dCvylqsCOCA6M2C6gybbCKrei8AQ="
      ];
    };
  };
}
