{
  lib,
  pkgs,
  ...
}:
let
  lockCommand = "pidof hyprlock || hyprlock";
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = lockCommand;
      };

      listener = [
        # Suspend after 10 seconds idle on the lock screen.
        {
          timeout = 10;
          on-timeout = ''
            hyprctl locked | grep true && \
              hyprctl dispatch 'hl.dsp.dpms({ action = "off" })' && \
              systemctl suspend
          '';
        }
        # Dim the screen to warn it will suspend soon.
        {
          timeout = 52;
          on-timeout = "${lib.getExe pkgs.brightnessctl} --save -e set 30%- --min-value 5%";
          on-resume = "${lib.getExe pkgs.brightnessctl} --restore";
        }
        # Lock and suspend.
        {
          timeout = 60;
          on-timeout = ''
            hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'; \
            loginctl lock-session; \
            systemctl suspend
          '';
        }
      ];
    };
  };
}
