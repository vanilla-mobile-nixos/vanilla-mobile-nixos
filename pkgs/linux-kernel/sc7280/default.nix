# How to update:
# - Have a local copy of <https://github.com/sc7280-mainline/linux>.
# - Vendor the patches using `../update-kernel-patches.sh sc7280 <repo> <Linux tag> <sc7280 tag>`.
# - Update the base Linux version below.
# - Refresh `fp5-patches` on top of the new sc7280 tag, dropping any that have been
#   merged. The QSEECOM TEE driver comes from <https://github.com/wrobelda/linux/tree/qcom-qseecom-tee>.
# - Check for changes to `fp5_defconfig`. Ex: `git diff v7.3.0-sc7280 <new tag> -- arch/arm64/configs/fp5_defconfig`
# - See `../sdm845/default.nix` for how to check the config.
{
  lib,
  fetchurl,
  buildLinux,
  linuxKernel,
  stdenv,
  # From `boot.kernelPatches` via `kernel.override`. Must be passed explicitly,
  # callPackage would fill in `pkgs.kernelPatches`.
  kernelPatches ? [ ],
  ...
}:
let
  kernel =
    let
      version = "7.3";
    in
    buildLinux {
      src = fetchurl {
        url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
        hash = "sha256:0ls902gz6h1ydcnwx2zzdcglg52f14hmaxk2ncg341hfy4j3qdl7";
      };
      inherit version;
      isLTS = false;
      modDirVersion = lib.versions.pad 3 version;
      extraMeta = {
        branch = "7.3";
        maintainers = with lib.maintainers; [ marcusramberg ];
        platforms = [ "aarch64-linux" ];
      };
    };
in
kernel.override {
  kernelPatches =
    with linuxKernel.kernelPatches;
    [
      bridge_stp_helper
      request_key_helper
    ]
    ++ (import ./kernel-patches)
    ++ (import ./fp5-patches)
    ++ [
      {
        # Some sort of ordering issue with parts of structuredExtraConfig.
        name = "config-fixes";
        patch = ../config_fixes.patch;
      }
    ]
    ++ kernelPatches;

  # Remove some mostly raspberry pi specific stuff.
  stdenv = lib.recursiveUpdate stdenv {
    hostPlatform.linux-kernel.extraConfig = "";
  };

  # Needs to match `system.boot.loader.kernelFile`.
  target = "vmlinuz.efi";

  # To deal with all the unused option errors.
  ignoreConfigErrors = true;
  structuredExtraConfig = with lib.kernel; {
    # systemd-boot under U-Boot's UEFI environment.
    EFI_ZBOOT = yes;

    # Root lives on UFS.
    SCSI_UFSHCD = yes;
    SCSI_UFSHCD_PLATFORM = yes;
    SCSI_UFS_QCOM = yes;
    RPMB = yes;
    PHY_QCOM_QMP = yes;
    PHY_QCOM_QMP_UFS = yes;
    QCOM_INLINE_CRYPTO_ENGINE = yes;

    # Display and touch for the initrd LUKS prompt. Their clock, DMA and bus
    # providers aren't pulled into the initrd as module dependencies.
    DRM_MSM = yes;
    SC_DISPCC_7280 = yes;
    SC_GPUCC_7280 = yes;
    QCOM_GPI_DMA = yes;
    I2C_QCOM_GENI = yes;
    SPI_QCOM_GENI = yes;

    # USB, so a gadget console works from the initrd.
    PHY_QCOM_QMP_COMBO = yes;
    PHY_QCOM_QMP_USB = yes;
    PHY_QCOM_USB_SNPS_FEMTO_V2 = yes;
    TYPEC = yes;

    # Same as sdm845.
    QCOM_LLCC = yes;
    QCOM_SOCINFO = yes;
    QCOM_RMTFS_MEM = yes;
    QCOM_APR = yes;
    POWER_RESET_QCOM_PON = yes;
    QCOM_SPMI_TEMP_ALARM = yes;
    INTERCONNECT_QCOM_OSM_L3 = yes;
    RPMSG_QCOM_GLINK_SMEM = yes;

    # A built-in legacy gadget driver claims the UDC at boot, and every configfs
    # gadget then fails to bind with -EBUSY.
    U_SERIAL_CONSOLE = yes;
    USB_G_SERIAL = module;

    TYPEC_DP_ALTMODE = module;

    # ModemManager uses QMI over QRTR. Probing these AT ports resets them and
    # slows modem startup.
    RPMSG_WWAN_CTRL = no;

    # The CLF is a plain NCI controller, driven by the st21nfc-nci patch.
    NFC = module;
    NFC_NCI = module;
    NFC_ST21NFC_NCI = module;

    # cams only registers subdevs once every sensor in the DT has bound.
    VIDEO_IMX800 = module;

    # Fingerprint sensor.
    TEE_QSEECOM = module;
    MISC_FOCALTECH_FP = module;

    # The FP5 DT has a VoiceMMode1 link; without q6voice the card never probes.
    SND_SOC_QDSP6_Q6VOICE = module;
  };
}
