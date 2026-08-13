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

  # For devices whose devices.toml entry sets
  # android_bootimg_header_version = 2, such as fairphone-fp5.
  #
  # Header version 2 carries the device tree in a section of its own, so the
  # DTB goes in with --dtb instead of being concatenated onto the kernel the
  # way the header-v0 builder above does it. The offsets come from the
  # device's pmaports deviceinfo.
  mkAndroidBootImageV2 =
    {
      uboot,
      page_size ? 4096,
      ramdisk_offset ? "0x01000000",
      second_offset ? "0x00000000",
      tags_offset ? "0x00000100",
      dtb_offset ? "0x01f00000",
    }:
    buildPackages.runCommand "${uboot.pname}-boot-image"
      {
        meta = {
          inherit (uboot.meta) license;
        };
      }
      ''
        gzip ${uboot}/u-boot-nodtb.bin -c > u-boot-nodtb.bin.gz

        # Make an empty gzip archive to use as the ramdisk.
        # Tauchgang does this "to make more compatible android boot images".
        printf "\0" | gzip --stdout > "empty.gz"

        mkdir -p $out

        ${lib.getExe' buildPackages.android-tools "mkbootimg"} \
          --header_version 2 \
          --base 0x0 \
          --kernel_offset 0x8000 \
          --ramdisk_offset ${ramdisk_offset} \
          --second_offset ${second_offset} \
          --tags_offset ${tags_offset} \
          --dtb_offset ${dtb_offset} \
          --pagesize ${toString page_size} \
          --os_patch_level 2028-09-21 \
          --ramdisk empty.gz \
          --kernel u-boot-nodtb.bin.gz \
          --dtb ${uboot}/u-boot.dtb \
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
