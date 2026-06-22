{
  config,
  lib,
  pkgs,
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

    sleepInhibitors = {
      enableDefault = lib.mkEnableOption "default sleep inhibitors";
      mpris.enable = lib.mkEnableOption "inhibiting sleep while MPRIS shows media playing";
      sshd.enable = lib.mkEnableOption "inhibiting sleep while an SSH daemon connection is active";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.upower = {
        enable = true;
        percentageLow = lib.mkDefault 15;
        percentageCritical = lib.mkDefault 5;
        percentageAction = lib.mkDefault 3;
        criticalPowerAction = "PowerOff";
      };

      services.tlp.enable = lib.mkDefault true;
    })

    (lib.mkIf cfg.sleepInhibitors.enableDefault {
      vanilla-mobile.powerManagement.sleepInhibitors = {
        mpris.enable = lib.mkDefault true;
        sshd.enable = lib.mkDefault true;
      };
    })
    (lib.mkIf cfg.sleepInhibitors.mpris.enable {
      systemd.user.services."mpris-inhibit-sleep" = {
        description = "Inhibit sleep while MPRIS shows media playing";

        wantedBy = [ "default.target" ];

        script = ''
          while true; do
            if ${lib.getExe pkgs.playerctl} -a status | grep -q "Playing"; then
              systemd-inhibit --what sleep \
                --who "mpris-inhibit-sleep.service" \
                --why "MPRIS media playing" \
                ${lib.getExe' pkgs.coreutils "sleep"} 1.1 &
            fi
            sleep 1
          done
        '';
      };
    })
    (lib.mkIf cfg.sleepInhibitors.sshd.enable {
      systemd.services."sshd-inhibit-sleep@" = {
        description = "Inhibit sleep when sshd connection is active";

        wantedBy = [ "sshd@.service" ];
        bindsTo = [ "sshd@.service" ];

        serviceConfig.ExecStart = ''
          systemd-inhibit --what sleep \
            --who "sshd-inhibit-sleep@%i.service" \
            --why "SSH session active" \
            ${lib.getExe' pkgs.coreutils "sleep"} infinity
        '';
      };
    })

  ];
}
