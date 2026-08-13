self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.device.fairphone-fp5;

  # FP5 UCM profile (the fp5-sndcard verb plus the conf.d lookup symlinks).
  # Merged with upstream alsa-ucm-conf and wired to ALSA_CONFIG_UCM2 by the
  # vanilla-mobile.alsa-ucm-conf module below, whose mergeWithDefault does a
  # symlinkJoin -- so alsa-lib is not rebuilt.
  fp5Ucm = pkgs.stdenvNoCC.mkDerivation {
    pname = "alsa-ucm-conf-fairphone-fp5";
    inherit (pkgs.alsa-ucm-conf) version;
    dontUnpack = true;
    installPhase = ''
      install -Dm644 ${./fp5-ucm/fp5.conf} "$out/share/alsa/ucm2/Fairphone/fp5/fp5.conf"
      install -Dm644 ${./fp5-ucm/HiFi.conf} "$out/share/alsa/ucm2/Fairphone/fp5/HiFi.conf"
      mkdir -p "$out/share/alsa/ucm2/conf.d/qcm6490"
      # Card long name on hardware is "fairphone-Fairphone5"; the spaced
      # variant is postmarketOS's older-kernel name, kept as a fallback.
      ln -s ../../Fairphone/fp5/fp5.conf \
        "$out/share/alsa/ucm2/conf.d/qcm6490/fairphone-Fairphone5.conf"
      ln -s ../../Fairphone/fp5/fp5.conf \
        "$out/share/alsa/ucm2/conf.d/qcm6490/Fairphone 5.conf"
    '';
  };
in
{
  options.vanilla-mobile.device.fairphone-fp5 = {
    enable = lib.mkEnableOption "Fairphone 5 (fairphone-fp5)";
  };

  config = lib.mkIf cfg.enable {
    warnings =
      if !config.boot.loader.systemd-boot.enable then
        [
          ''
            systemd-boot is disabled. fairphone-fp5 has currently only
            been configured/tested for systemd-boot.
          ''
        ]
      else
        [ ];

    vanilla-mobile = {
      deviceInfo = {
        name = "Fairphone 5";
        codename = "fairphone-fp5";
        manufacturer = "Fairphone";
        dtb = "qcom/qcm6490-fairphone-fp5.dtb";
        # fastboot reports logical-block-size 0x1000 on this device.
        imageSectorSize = 4096;
        firmware = self.packages.fairphone-fp5-firmware;
        uboot = self.packages.ubootPackages.fairphone-fp5-boot-image;
      };
      soc.qcm6490.enable = true;
      # NFC controller (st21nfcd) is wired in the kernel; turn on the neard
      # userspace so tags can be read.
      soc.qcm6490.nfc.enable = true;
    };

    # Voice calls need q6voiced, which needs the modem's ALSA card and device
    # numbers. Read them off the phone once it boots:
    #   alsactl info
    # then fill these in and enable the service. Left off rather than guessed,
    # because wrong numbers route call audio to the wrong PCM.
    #
    # services.q6voiced = {
    #   enable = true;
    #   settings = {
    #     q6voice_card = 0;
    #     q6voice_device = 0;
    #   };
    # };

    # UCM for the fp5-sndcard: routes the q6 frontends to the speaker amps,
    # WCD capture and DisplayPort backends. The module sets ALSA_CONFIG_UCM2
    # on every relevant service (PipeWire/WirePlumber/pulse) and the CLIs.
    vanilla-mobile.alsa-ucm-conf = lib.mkIf config.vanilla-mobile.soc.qcm6490.audio.enable {
      enable = true;
      package = fp5Ucm;
      mergeWithDefault = true;
    };

    # The dw9719 focus actuator (DW9800K) intermittently fails its first
    # probe at boot with a CCI write timeout (-110) and i2c drivers are not
    # re-probed on deferral the way platform devices are. A bind attempted
    # once the system is up succeeds. Idempotent: skipped when already bound.
    systemd.services.fp5-rebind-focus = {
      description = "Rebind the rear-camera focus actuator if its boot-time probe failed";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "fp5-rebind-focus" ''
          # The bind still fails when attempted too soon after boot (the CCI
          # write times out), so retry for up to half a minute.
          for _ in 1 2 3 4 5 6; do
            bound=1
            for d in /sys/bus/i2c/devices/*-000e; do
              n=$(basename "$d")
              [ -e "/sys/bus/i2c/drivers/dw9719/$n" ] && continue
              echo "$n" > /sys/bus/i2c/drivers/dw9719/bind 2>/dev/null || bound=0
            done
            [ "$bound" = 1 ] && exit 0
            sleep 5
          done
          exit 1
        '';
      };
    };

    # Screen auto-rotation. mutter 50.2 permanently inhibits its orientation
    # tracking on a portrait phone with no tablet-mode switch: the first
    # event runs a docked-convertible workaround that inhibits tracking, and
    # with no dock transition to balance it the accelerometer is released
    # forever. mutter main fixed this with an idempotent inhibit; the patch
    # backports it.
    nixpkgs.overlays = [
      (final: prev: {
        mutter = prev.mutter.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./mutter-portrait-autorotate.patch
          ];
        });
      })
    ];

    # Orientation of the accelerometer as mounted in this chassis. Without it
    # the sensor reports in its own frame and screen rotation is inverted.
    # Matches the same DSP nodes the SSC opt-in in soc/qcm6490 tags.
    #
    # A 180 degree rotation in the screen plane: X and Y negated, Z left alone.
    # Z was negated here too, which made a phone lying face up report
    # "face-down". That matrix also had determinant -1, making it a reflection
    # rather than a rotation, which no physical mounting can be.
    services.udev.extraRules = ''
      SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, -1, 0; 0, 0, 1"
      SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, -1, 0; 0, 0, 1"
    '';

    boot = {
      kernelParams = [
        # The default probe-timeout elapses while the initrd waits at the
        # LUKS prompt (nothing registers there), so msm-mdss fails -110
        # instead of deferring and the panel never binds. No finite value is
        # correct since the prompt is unbounded; a negative value disables
        # the timer.
        "deferred_probe_timeout=-1"
      ];

      initrd.kernelModules = [
        # Needed to reach the UFS the rootfs lives on.
        "phy_qcom_qmp_ufs"
        "ufs_qcom"
        # Display, so the boot stage is not a black screen. The panel driver
        # alone is not enough - without `msm` there is no DRM driver for it to
        # attach to and nothing is drawn.
        "msm"
        "panel_raydium_rm692e5"
        # The DPU is a component master and will not bind until *every*
        # component registers, and the DisplayPort controller is one of them.
        # It hangs off the USB-C DP redriver: ptn36502 -> pmic_glink_altmode's
        # retimer-switch -> aux_hpd_bridge -> displayport-controller. Any of
        # these probing late takes the internal panel down with it, so the
        # whole chain is loaded here rather than from the rootfs.
        "ptn36502"
        "phy_qcom_qmp_combo"
        "pmic_glink"
        "pmic_glink_altmode"
        "qcom_glink_smem"
        "aux_bridge"
        "aux_hpd_bridge"
        "fsa4480"
        # Touchscreen, so the passphrase can actually be typed on the
        # on-screen keyboard. The panel alone gets you a keyboard that draws
        # but does not respond. goodix,gt9897 hangs off &spi13, so the SPI
        # controller and its DMA engine are needed too, not just the
        # touchscreen driver.
        "gpi"
        "spi_geni_qcom"
        "goodix_berlin_spi"
      ];
    };
  };
}
