[
  {
    # Add patch to fix glitches on bridghtness change.
    # Taken from this pmos issue:
    # https://gitlab.postmarketos.org/postmarketOS/pmaports/-/work_items/4274
    name = "fp5-dsi-skip-link-clk-cycling";
    patch = ./0001-fp5-dsi-skip-link-clk-cycling.patch;
  }
  {
    # Bluetooth HCI fix for registration on fp5
    name = "hci-qca-drop-unused-event";
    patch = ./0002-hci-qca-drop-unused-event.patch;
  }
  {
    # The LPASS LPI pinctrl's clocks are provided by the ADSP (q6prm over
    # GLINK). If the pinctrl probes before the ADSP remoteproc has booted,
    # the clock enable times out and the probe fails permanently, leaving
    # the sound card stuck in deferred probe. Return -EPROBE_DEFER instead
    # so the probe is retried once the ADSP is up.
    name = "pinctrl-lpass-lpi-defer-on-clk-timeout";
    patch = ./0003-pinctrl-lpass-lpi-defer-on-clk-timeout.patch;
  }
  {
    # Raw-NCI/I2C driver for the FP5 ST21NFCD. The chip is a plain NCI
    # controller (3-byte header, IRQ-driven, no NDLC link layer), so the
    # mainline st-nci driver does not fit; this registers an nci_dev and
    # lets the kernel NCI core drive it.
    name = "nfc-st21nfc-nci-driver";
    patch = ./0004-nfc-st21nfc-nci-driver.patch;
  }
  {
    # Add the ST21NFCD NFC controller device tree node on I2C9.
    # Hardware details from Fairphone 5 Android kernel source.
    name = "dts-add-st21nfcd-nfc";
    patch = ./0005-dts-add-st21nfcd-nfc.patch;
  }
  {
    # Enable 4-lane DisplayPort via QMP Combo PHY mode-switch.
    # Adds mode-switch property to the PHY, wires data-lanes=<0 1 2 3>
    # in the SoC dtsi, and removes the now-redundant board-level override.
    name = "dts-kodiak-4lane-dp-mode-switch";
    patch = ./0006-dts-kodiak-4lane-dp-mode-switch.patch;
  }
  {
    # SC7280/QCM6490 has only one DSPP block (DSPP_0, paired with LM_0).
    # In a dual-display setup (internal DSI + external DP), when both CRTCs
    # request color management, the second CRTC cannot reserve mixers with a
    # DSPP and DP hotplug fails ("unable to find appropriate mixers", -119).
    # Retry the reservation without DSPP so the external display works
    # (without hw color management) rather than failing entirely.
    # https://github.com/sc7280-mainline/linux/pull/22
    name = "dpu-dspp-reservation-fallback";
    patch = ./0007-dpu-dspp-reservation-fallback.patch;
  }
  {
    # qmp_combo_typec_mux_set() drops a QMPPHY mode switch requested while
    # the DP PHY is still powered on -- "delaying switch" is never retried.
    # Unplugging a DP+USB3 dock leaves qmpphy_mode stuck at USB3DP; the next
    # suspend tears the PHY down, and the following plug takes the "same
    # qmpphy mode" early return, so the PHY is never reprogrammed. Both
    # DisplayPort and USB3 stay dead until reboot. Apply the deferred switch
    # from qmp_combo_dp_power_off() once the DP PHY is down.
    name = "qmp-combo-apply-deferred-mode-switch";
    patch = ./0008-qmp-combo-apply-deferred-mode-switch.patch;
  }
  {
    # qmp_combo_apply_mode() discards the result of qmp_combo_usb_power_on(), which
    # can fail: it polls PHYSTATUS with a 10 ms timeout and gives up with -ETIMEDOUT
    # if the USB3 PHY does not come out of reset.
    name = "qmp-combo-do-not-latch";
    patch = ./0009-qmp-combo-do-not-latch-unapplied-mode.patch;
  }
  {
    # libcamera probes the sensor sub-device for crop/native-size selection
    # targets to derive the pixel array geometry. Neither FP5 sensor answered
    # them ("the sensor kernel driver needs to be fixed"): imx858 had no
    # .get_selection, and s5kjn1's only handled CROP/CROP_BOUNDS, reported the
    # per-mode size, and copied width into height (8160x8160 active area).
    # Report the full native array for all crop targets on both sensors.
    name = "media-fp5-sensor-crop-selection";
    patch = ./0010-media-fp5-sensor-crop-selection.patch;
  }
  {
    # imx858_power_on() released reset before enabling MCLK and waited only
    # ~1ms; Sony sensors need MCLK stable before XCLR is deasserted. Cold boot
    # worked by luck, but a runtime-PM power cycle (camera app restart) raced,
    # NAKing the first i2c and wedging the GENI bus ("Timeout resetting
    # RX_FSM"). Reorder to regulators -> MCLK -> settle -> release reset.
    name = "media-imx858-power-on-ordering";
    patch = ./0011-media-imx858-power-on-ordering.patch;
  }
  {
    # QSEECOM TEE driver: exposes QSEE trusted applications through the TEE
    # subsystem (/dev/tee*), so user space can load an application from
    # /lib/firmware, open a session to it and invoke commands, and so a
    # supplicant can answer the listener services (file service, RPMB, time)
    # that a trusted application needs the normal world to run.
    #
    # QSEE is the command-based Qualcomm interface; the in-tree qcomtee
    # driver serves the object-based smcinvoke one, and a trusted application
    # is built against one or the other. The FP5 fingerprint application
    # (focal32, FocalTech FT9362) answers only over QSEECOM.
    #
    # Squashed from the `qcom-qseecom-tee` series (42 commits, based on
    # v7.1) by Dawid Wróbel, https://github.com/wrobelda/linux — not yet
    # posted upstream. Also extends soc/qcom mdt_loader to assemble a
    # split firmware image into one contiguous blob, which the driver
    # needs to hand an application to TZ.
    name = "tee-qseecom-driver";
    patch = ./0012-tee-qseecom-driver.patch;
  }
  {
    # QSEECOM binds only on machines in an explicit allowlist in qcom_scm.
    # Add "fairphone,fp5".
    name = "qcom-scm-qseecom-fp5-allowlist";
    patch = ./0013-qcom-scm-qseecom-fp5-allowlist.patch;
  }
  {
    # TZ refuses an invoke whose request is 16 bytes or more with "invalid
    # argument", and takes the same request one byte shorter -- the boundary
    # does not move with the response size, so what it objects to is where
    # the response begins. The vendor HAL's shared buffer is a page-aligned
    # request region (0x78000) followed by a page-aligned response region
    # (0x8040), so stage the response on a page boundary too.
    #
    # The FP5 fingerprint application needs this: its command header is 16
    # bytes, so every command it accepts was one the secure world refused.
    name = "tee-qseecom-align-response";
    patch = ./0014-tee-qseecom-align-response.patch;
  }
  {
    # The fingerprint application answers in the request buffer, not the
    # response one: it writes its result into the request header at +8 and
    # sets bit 31 of the command id to say it answered. The driver stages
    # the request in its own memory and copied only the response back, so
    # that answer was dropped. Copy the request back when the client passes
    # it as an inout memref.
    name = "tee-qseecom-request-writeback";
    patch = ./0015-tee-qseecom-request-writeback.patch;
  }
  {
    # The FP5's fingerprint sensor is a FocalTech FT9362 in the power button.
    # Its SPI bus belongs to the secure world, so this driver owns only what
    # Linux is left with: the reset and power pins, and the interrupt. The
    # trusted application expects the sensor powered and out of reset before
    # it will talk to it.
    name = "misc-focaltech-fp-driver";
    patch = ./0016-misc-focaltech-fp-driver.patch;
  }
  {
    # The sensor's node and its pinctrl states: reset on GPIO35, power on
    # GPIO60, interrupt on GPIO34. Pin numbers and the pinctrl state names
    # the driver looks up both come from the Fairphone vendor kernel.
    name = "dts-fp5-fingerprint-sensor";
    patch = ./0017-dts-fp5-fingerprint-sensor.patch;
  }
  {
    # The connector change work runs on the unfreezable system_wq, so a
    # cable plug that wakes the phone is handled before the geni i2c
    # controllers resume. It reaches ->connector_status(), which writes the
    # orientation to the fsa4480 switch and the ptn36502 redriver over i2c,
    # and the transfer is refused with -ESHUTDOWN ("Transfer while
    # suspended") -- so the orientation is lost, not just warned about.
    name = "ucsi-connector-change-on-freezable-wq";
    patch = ./0018-ucsi-connector-change-on-freezable-wq.patch;
  }
  {
    # Same bug on the altmode notification path, fixed upstream by Abel
    # Vesa; not in this tree yet.
    name = "pmic-glink-altmode-freezable-wq";
    patch = ./0019-pmic-glink-altmode-freezable-wq.patch;
  }
  {
    # The BT UART's wakeup IRQ watches an edge on RX, and that edge latches
    # in the PDC even while masked. The in-band sleep handshake with the
    # Bluetooth controller happens as the port suspends, so the IRQ is
    # already pending when dpm_suspend_noirq() arms it -- it fires at once
    # and every suspend aborts with "Wakeup pending. Abort CPU freeze".
    # Clear the stale edge after the port has suspended, which keeps
    # wake-on-Bluetooth working (masking the port's wakeup does not).
    name = "qcom-geni-serial-clear-stale-wakeup-edge";
    patch = ./0020-qcom-geni-serial-clear-stale-wakeup-edge.patch;
  }
]
