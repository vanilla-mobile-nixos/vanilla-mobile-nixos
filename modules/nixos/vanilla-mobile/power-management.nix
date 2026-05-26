{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.powerManagement;
in
{
  options.vanilla-mobile.powerManagement = {
    enable = lib.mkEnableOption "basic power management" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.upower = {
      enable = true;
      percentageLow = lib.mkDefault 15;
      percentageCritical = lib.mkDefault 5;
      percentageAction = lib.mkDefault 3;
      criticalPowerAction = "PowerOff";
    };

    services.tlp.enable = lib.mkDefault true;
  };
}
