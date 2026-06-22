{ config, lib, ... }:
let
  cfg = config.vanilla-mobile.plymouth;
in
{
  options.vanilla-mobile.plymouth = {
    mobileTweaks.enable = lib.mkEnableOption "plymouth mobile tweaks";
    unl0krSupport.enable = lib.mkEnableOption "unl0kr support";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.mobileTweaks.enable {
      boot.plymouth = {
        # Allow using the power button to toggle Plymouth splash.
        extraConfig = ''
          XkbExtraEscButton=0x1008ff2a  # XKB_KEY_XF86PowerOff
        '';
      };
    })
    (lib.mkIf (cfg.unl0krSupport.enable && config.boot.plymouth.enable) {
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
    })
  ];
}
