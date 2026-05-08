{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.uboot;
in
{
  options.vanilla-mobile.uboot = {
    enable = lib.mkEnableOption "UBoot";
  };

  config = lib.mkIf cfg.enable {
    boot.loader = {
      efi.canTouchEfiVariables = false;

      # Currently only tested on systemd-boot.
      grub.enable = lib.mkDefault false;
      systemd-boot = {
        enable = lib.mkDefault true;
        editor = lib.mkDefault false;
      };
    };
  };
}
