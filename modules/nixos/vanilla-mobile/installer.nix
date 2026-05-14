{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.installer;
in
{
  options.vanilla-mobile.installer = {
    enable = lib.mkEnableOption "installer mode";
  };

  config = lib.mkIf cfg.enable {
    # Allow SSH over USB.
    systemd.services.usb-moded-turn-off-rescue-mode.enable = false;

    # Allow touch typing in the TTY.
    services.buffyboard = {
      enable = true;
      settings.input.touchscreen = true;
    };
  };
}
