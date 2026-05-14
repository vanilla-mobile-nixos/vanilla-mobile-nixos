{
  lib,
  ...
}:
{
  # Most of this information can be found in postmarketOS `deviceinfo` files.
  # Example: <https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/main/device/community/device-xiaomi-beryllium/deviceinfo>
  options.vanilla-mobile.deviceInfo = {
    name = lib.mkOption {
      type = lib.types.str;
      example = "Xiaomi Poco F1";
    };
    codename = lib.mkOption {
      type = lib.types.str;
      example = "xiaomi-beryllium";
    };
    manufacturer = lib.mkOption {
      type = lib.types.str;
      example = "Xiaomi";
    };

    dtb = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "qcom/sdm845-xiaomi-beryllium-tianma";
      description = "Name of the device tree blob file";
    };
    # `rootfs_image_sector_size` in postmarketOS
    imageSectorSize = lib.mkOption {
      type = lib.types.int;
      default = 512;
      example = 4096;
      description = "Sector size used for the images to be flashed.";
    };
    firmware = lib.mkOption {
      type = with lib.types; nullOr package;
      default = null;
      description = "Device specific firmware.";
    };
    uboot = lib.mkOption {
      type = with lib.types; nullOr package;
      default = null;
      description = "What the user can flash to their phone to have UBoot.";
    };

  };
}
