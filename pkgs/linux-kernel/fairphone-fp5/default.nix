# Kernel for the Fairphone 5 (qcm6490): mainline plus the board bits that are
# not upstream.
#
# Mainline already has the SoC support, every audio driver the phone needs
# (aw88261, wcd938x, lpass rx/tx macros) and the front camera. Missing are the
# board audio wiring, the rear camera wiring and the imx858 driver, all taken
# from <https://github.com/sc7280-mainline/linux> and carried in
# ./fairphone-fp5-board-support.patch.
#
# The patch has to go through kernelPatches rather than postPatch: the kernel
# config is built by a separate derivation that inherits `patches` but takes
# its postPatch from build.nix, so a postPatch here is silently dropped and
# the Kconfig entry never exists when the config is generated.
#
# How to update:
# - Regenerate the patch with ./update-board-patch.sh against a newer tree.
# - The .dtsi files inside it are label-referenced, so unrelated churn does not
#   break them; dtc fails the build if a referenced label disappears.
{
  lib,
  linuxKernel,
  stdenv,
  ...
}:
let
  kernel = linuxKernel.kernels.linux_7_1;
in
kernel.override {
  argsOverride = {
    version = "${kernel.version}-fp5";
    inherit (kernel) modDirVersion;

    extraMeta = {
      description = "Linux kernel for the Fairphone 5";
      platforms = [ "aarch64-linux" ];
    };
  };

  kernelPatches = [
    {
      name = "fairphone-fp5-board-support";
      patch = ./fairphone-fp5-board-support.patch;
    }
    # Without this the device intermittently boots to a black screen: the
    # PTN36502 redriver fails its i2c probe when it runs after the regulator
    # core has powered its rail down, and the DP controller it blocks is a
    # required component of the DPU aggregate, so the internal panel never
    # lights. Kept separate from the board-support patch above because that
    # one is regenerated wholesale by ./update-board-patch.sh.
    {
      name = "ptn36502-redriver-startup-delay";
      patch = ./ptn36502-redriver-startup-delay.patch;
    }
    # WCN6750 sends the baudrate-change command complete event
    # asynchronously; hci_qca mistakes it for the response to a later command
    # and the controller never finishes registering:
    #
    #   Bluetooth: hci0: unexpected event for opcode 0xfc48
    #
    # Unmerged upstream as of 7.1.5.
    {
      name = "hci-qca-drop-unused-event";
      patch = ./hci-qca-drop-unused-event.patch;
    }
    # Speaker amps and AFE clock voting. Without these the aw88261 amps never
    # leave "device start failed" and the speakers make no sound on mainline.
    # The aw88261 side is the FROMLIST series tested on this phone; the q6afe
    # hunk fixes the LPASS clock-vote response being misread. Both unmerged
    # as of 7.1.5.
    {
      name = "aw88261-and-q6afe-fixes";
      patch = ./aw88261-and-q6afe-fixes.patch;
    }
    # Every qcom adc-tm thermal zone (the 8 PMIC thermistor zones on this
    # phone) returns -EINVAL: iio_read_channel_processed() has returned 0 on
    # success since the iio_multiply_value() refactor, but adc_tm5_get_temp
    # still expects the old convention of returning IIO_VAL_INT. The raw IIO
    # channels read fine; only this check fails. Still broken in mainline
    # master as of 2026-08-11 -- worth reporting upstream.
    {
      name = "adc-tm5-processed-read";
      patch = ./adc-tm5-processed-read.patch;
    }
    # NFC. The chip is on i2c9 at 0x08 (mainline's "@ 28" comment copies a
    # sloppy downstream node name; the downstream reg and a live probe both
    # say 0x08), reset on gpio38, IRQ on gpio41, and it speaks raw NCI 2.0
    # over I2C -- no NDLC framing -- so the existing st-nci driver cannot
    # attach. Adds a small raw-NCI driver modeled on nxp-nci plus the DT
    # node. Candidate for upstreaming.
    {
      name = "st21nfcd-nfc-driver";
      patch = ./st21nfcd-nfc-driver.patch;
    }
    # Fingerprint. The FP5's FocalTech sensor sits on an SPI bus that belongs
    # to the secure world (verified: TLMM gpio-reserved-ranges reserves the
    # SE6 pins 56-59), so imaging and matching happen inside a signed
    # TrustZone application ("focal32"). The normal world's job is to load and
    # talk to that application over the QSEECOM command interface. Mainline
    # already carries the QSEECOM SCM glue (qcom_qseecom.c) and the allowlist;
    # these patches add the QSEECOM *TEE* driver that exposes trusted apps
    # through /dev/tee*, plus the misc driver that owns the sensor's reset/
    # power/irq GPIOs and the DT node. Imported from
    # github.com/marcusramberg/nixos-fairphone-fp5; they apply cleanly to
    # mainline 7.1.5.
    {
      name = "qcom-scm-qseecom-fp5-allowlist";
      patch = ./qcom-scm-qseecom-fp5-allowlist.patch;
    }
    {
      name = "tee-qseecom-driver";
      patch = ./tee-qseecom-driver.patch;
    }
    {
      name = "tee-qseecom-align-response";
      patch = ./tee-qseecom-align-response.patch;
    }
    {
      name = "tee-qseecom-request-writeback";
      patch = ./tee-qseecom-request-writeback.patch;
    }
    {
      name = "misc-focaltech-fp-driver";
      patch = ./misc-focaltech-fp-driver.patch;
    }
    {
      name = "dts-fp5-fingerprint-sensor";
      patch = ./dts-fp5-fingerprint-sensor.patch;
    }
  ];

  # Remove some mostly raspberry pi specific stuff.
  stdenv = lib.recursiveUpdate stdenv {
    hostPlatform.linux-kernel.extraConfig = "";
  };

  structuredExtraConfig = with lib.kernel; {
    # Rear camera, from the out-of-tree driver in the patch above.
    VIDEO_IMX858 = module;

    # Rear camera focus. The actuator node's "dongwoon,dw9800k" is matched
    # by the dw9719 driver (mainline has carried the DW9800K variant since
    # before 7.1.5); the driver was simply never enabled, which is why the
    # lens never bound and focus stayed fixed.
    VIDEO_DW9719 = module;

    # Board audio. These drivers are all already in mainline.
    SND_SOC_AW88261 = module;
    SND_SOC_WCD938X_SDW = module;
    SND_SOC_LPASS_RX_MACRO = module;
    SND_SOC_LPASS_TX_MACRO = module;
    SND_SOC_LPASS_VA_MACRO = module;
    SND_SOC_QCOM_COMMON = module;
    SND_SOC_SC7280 = module;
    SOUNDWIRE_QCOM = module;

    # NFC: the NCI core plus the raw-NCI ST21NFCD driver added by the patch
    # above.
    NFC = module;
    NFC_NCI = module;
    NFC_ST21NFCD_I2C = module;

    # Fingerprint: the TEE core, the QSEECOM SCM interface and mdt loader it
    # builds on, the QSEECOM TEE driver that loads the focal32 trusted
    # application, and the misc driver owning the sensor's GPIOs.
    TEE = module;
    QCOM_QSEECOM = yes;
    QCOM_MDT_LOADER = yes;
    TEE_QSEECOM = module;
    MISC_FOCALTECH_FP = module;

    # Wanted by the NixOS LUKS module.
    DM_CRYPT = module;
    CRYPTO_CRYPTD = module;
    CRYPTO_USER_API_SKCIPHER = module;
    CRYPTO_LRW = module;
  };
}
