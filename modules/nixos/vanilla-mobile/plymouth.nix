{ config, lib, ... }:
{
  config = lib.mkIf config.boot.plymouth.enable {
    boot.plymouth = {
      # Allow using the power button to toggle Plymouth splash.
      extraConfig = ''
        XkbExtraEscButton=0x1008ff2a  # XKB_KEY_XF86PowerOff
      '';
    };

    # Unl0kr support
    boot.initrd.systemd =
      let
        plymouth = lib.getExe' config.boot.plymouth.package "plymouth";
      in
      lib.mkIf config.boot.initrd.unl0kr.enable {
        # Disable upstream `ConditionPathExists=!/run/plymouth/pid`.
        paths.unl0kr-agent.unitConfig.ConditionPathExists = [ "" ];

        services.unl0kr-agent = {
          # Disable upstream `ConditionPathExists=!/run/plymouth/pid`.
          unitConfig.ConditionPathExists = [ "" ];

          preStart = "${plymouth} --ping && ${plymouth} deactivate";
          postStop = "${plymouth} --ping && ${plymouth} reactivate";
        };

        # Disable Plymouth password prompt.
        paths.systemd-ask-password-plymouth.enable = false;
        services.systemd-ask-password-plymouth.enable = false;
      };
  };
}
