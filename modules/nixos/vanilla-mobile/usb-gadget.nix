self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.usb-gadget;
in
{
  options.vanilla-mobile.usb-gadget = {
    enable = lib.mkEnableOption "USB gadget configurations and daemons";

    network = {
      serverAddress = lib.mkOption {
        type = lib.types.str;
        default = "172.16.42.1";
      };
      clientAddress = lib.mkOption {
        type = lib.types.str;
        default = "172.16.42.2";
      };
    };
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
        ExecStart = ''
          ${lib.getExe self.packages.unudhcpd} -i usb0 -s \
              ${cfg.network.serverAddress} -c ${cfg.network.clientAddress}'';
      };
    };

    services.usb-moded = {
      enable = true;

      settings = {
        configfs = {
          gadget_base_directory = "/sys/kernel/config/usb_gadget/g1";
          gadget_conf_directory = "configs/c.1";
        };

        network.ip = cfg.network.serverAddress;
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
    services.usb-moded-notify.enable = lib.mkDefault true;

  };
}
