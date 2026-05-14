# The reason to use `usb-moded` instead of just making the network gadget and using it
# without `usb-moded` is that `usb-moded` easily allows for other USB gadget modes like
# MTP, tethering, or even potentially Android Auto in the future.
self:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  vanilla-mobile-pkgs = self.packages.${pkgs.stdenv.hostPlatform.system};

  cfg = config.services.usb-moded;

  iniFormat = pkgs.formats.ini { };
in
{
  options.services.usb-moded = {
    enable = lib.mkEnableOption "usb-moded";
    package = lib.mkPackageOption vanilla-mobile-pkgs "usb-moded" { };

    settings = lib.mkOption {
      inherit (iniFormat) type;
      default = { };
    };

    modes = lib.mkOption {
      type = with lib.types; attrsOf iniFormat.type;
      default = { };
    };
    appsync = lib.mkOption {
      type = with lib.types; attrsOf iniFormat.type;
      default = { };
      description = "Configurations for what to run when a given mode is started.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.usb-moded = {
      # Default mode.
      settings.usbmode.mode = lib.mkDefault "charging_only";
    };

    services.dbus.packages = [ cfg.package ];

    systemd = {
      packages = [ cfg.package ];
      services = {
        usb-moded = {
          wantedBy = [ "basic.target" ];
          after = [ "usb-gadget.service" ];

          path = [ pkgs.unixtools.ifconfig ];

          environment = {
            # Start in rescue mode.
            USB_MODED_ARGS = "-r";
            USB_MODED_HW_ADAPTATION_ARGS = "";
          };
        };

        usb-moded-turn-off-rescue-mode = {
          description = "Turn off usb-moded rescue mode";

          wantedBy = [ "graphical.target" ];
          after = [
            "graphical.target"
            "usb-moded.service"
          ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = [
              "busctl emit /com/nokia/startup/signal com.nokia.startup.signal init_done"
              ''busctl call com.meego.usb_moded /com/meego/usb_moded com.meego.usb_moded set_mode s "${cfg.settings.usbmode.mode}"''
            ];
          };
        };
      };
    };

    environment.etc = {
      "usb-moded/nixos-settings.ini".source =
        iniFormat.generate "usb-moded-nixos-settings.ini" cfg.settings;
    }
    # Dynamic modes
    // (lib.mapAttrs' (
      name: value:
      lib.nameValuePair "usb-moded/dyn-modes/${name}.ini" {
        source = iniFormat.generate "usb-moded-${name}-mode.ini" value;
      }
    ) cfg.modes)
    # Appsync run files
    // (lib.mapAttrs' (
      name: value:
      lib.nameValuePair "usb-moded/run/${name}.ini" {
        source = iniFormat.generate "usb-moded-${name}-run.ini" value;
      }
    ) cfg.appsync);
  };
}
