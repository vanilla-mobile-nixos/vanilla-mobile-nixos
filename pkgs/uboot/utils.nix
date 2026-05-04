{
  lib,
  buildPackages,
  fetchFromGitLab,
  buildUBoot,
  unixtools,
}:

{
  buildTauchgangUBoot =
    {
      pname,
      dtb,
      defconfig,
    }:
    (buildUBoot {
      pname = "uboot-tauchgang-${pname}";
      version = "2026.07-rc1";

      src = fetchFromGitLab {
        domain = "gitlab.postmarketos.org";
        owner = "tauchgang";
        repo = "u-boot";
        rev = "1f56592576887ffcae0e7d44c66b5cf030674908";
        hash = "sha256-A6AombRRnUaHkn7Fn7p6tkAEYnA+Z4vaJliRVB0hKuo=";
      };

      defconfig = "${defconfig} tauchgang.config";
      extraConfig = ''
        CONFIG_DEFAULT_DEVICE_TREE="${dtb}"
      '';

      filesToInstall = [
        "u-boot-nodtb.bin"
        "u-boot.dtb"
      ];

      extraMeta.platforms = [ "aarch64-linux" ];
    }).overrideAttrs
      (oldAttrs: {
        nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ unixtools.xxd ];
      });

  mkAndroidBootImage =
    {
      uboot,
      page_size ? 4096,
    }:
    buildPackages.runCommand "${uboot.pname}-boot-image"
      {
        meta = {
          inherit (uboot.meta) license;
        };
      }
      ''
        gzip ${uboot}/u-boot-nodtb.bin -c > u-boot-nodtb.bin.gz
        cat u-boot-nodtb.bin.gz ${uboot}/u-boot.dtb > u-boot.bin.gz

        # Make an empty gzip archive to use as the ramdisk.
        # Tauchgang does this "to make more compatible android boot images".
        printf "\0" | gzip --stdout > "empty.gz"

        mkdir -p $out

        ${lib.getExe' buildPackages.android-tools "mkbootimg"} \
          --base 0x0 \
          --kernel_offset 0x8000 \
          --pagesize ${toString page_size} \
          --os_patch_level 2028-09-21 \
          --ramdisk empty.gz \
          --kernel u-boot.bin.gz \
          -o $out/u-boot.img
      '';
  mkAndroidBootImageQCDT =
    {
      uboot,
      page_size,
      device_tree_image,
    }:
    buildPackages.runCommand "${uboot.pname}-boot-image"
      {
        meta = {
          inherit (uboot.meta) license;
        };
      }
      ''
        gzip ${uboot}/u-boot-nodtb.bin -c > u-boot-nodtb.bin.gz
        cat u-boot-nodtb.bin.gz ${uboot}/u-boot.dtb > u-boot.bin.gz

        # Make an empty gzip archive to use as the ramdisk.
        # Tauchgang does this "to make more compatible android boot images".
        printf "\0" | gzip --stdout > "empty.gz"

        mkdir -p $out

        ${lib.getExe' buildPackages.mkbootimg-osm0sis "mkbootimg"} \
          --base 0x0 \
          --kernel_offset 0x8000 \
          --pagesize ${toString page_size} \
          --os_patch_level 2028-09-21 \
          --ramdisk empty.gz \
          --kernel u-boot.bin.gz \
          --dt ${device_tree_image} \
          -o $out/u-boot.img
      '';
}
