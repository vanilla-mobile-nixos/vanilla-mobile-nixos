self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  vanilla-mobile-pkgs = self.packages.${pkgs.stdenv.hostPlatform.system};

  cfg = config.vanilla-mobile.usb-gadget;
in
{
  options.vanilla-mobile.usb-gadget = {
    enable = lib.mkEnableOption "USB gadget configurations and daemons";
  };

  config = lib.mkIf cfg.enable {
    hardware.usb-gadget = {
      enable = true;
      usbManufacturer = config.vanilla-mobile.deviceInfo.manufacturer;
      usbProduct = config.vanilla-mobile.deviceInfo.name;
    };

    systemd.services.usb-gadget-unudhcpd = {
      description = "DHCP server for USB Gadget";
      serviceConfig = {
        ExecStart = [
          "${lib.getExe vanilla-mobile-pkgs.unudhcpd} -i usb0 -s 172.16.42.1 -c 172.16.42.2"
        ];
      };
    };

    services.usb-moded = {
      enable = true;

      settings = {
        configfs = {
          gadget_base_directory = "/sys/kernel/config/usb_gadget/g1";
          gadget_conf_directory = "configs/c.1";
        };

        network.ip = "172.16.42.1";
      };

      modes = {
        # USB network mode.
        developer_mode = {
          mode = {
            name = "developer_mode";
            module = "none";
            network = 1;
            appsync = 1;
          };
          options = {
            sysfs_value = "ncm.usb0";
            dhcp_server = 0;
          };
        };
      };
      appsync = {
        developer-unudhcpd.info = {
          systemd = 1;
          name = "usb-gadget-unudhcpd.service";
          mode = "developer_mode";
          post = 1;
        };
      };
    };

  };
}
