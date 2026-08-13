# Fairphone 5 (fairphone-fp5)

The Fairphone 5 is a Qualcomm QCM6490 (SC7280-class) device. This port runs a
mainline `linux_7_1` kernel with a set of board patches, plus userspace for the
Qualcomm remote processors, audio, NFC and fingerprint.

## Setup

The install follows the same shape as the other devices (see
[xiaomi-beryllium](./xiaomi-beryllium.md) for the general flow); the
device-specific facts are:

- Bootloader must be unlocked (`fastboot flashing unlock`).
- The example config is `examples/installConfigs/fairphone-fp5`
  (`configuration.nix` + `disko-config.nix`). Root is LUKS + Btrfs; the vendor
  `persist` partition is kept and mounted at `/persist`.
- Flashing is by partition (`fastboot flash`), not repartitioning. The A/B
  layout is retained; the config marks the booted slot good each boot.
- The kernel is not in any binary cache, so cross-compile it
  (`vanilla-mobile.installer.enableCrossPkgs = true`) rather than emulate.
- The fingerprint trusted-application image is device-specific and unfree; it
  is not shipped here. Extract it from your own device's factory image with
  `pkgs/focal32-firmware/extract-from-factory.sh FP5-XXXX-factory.zip`, put the
  result inside your own configuration, and point the module at it with
  `vanilla-mobile.soc.qcm6490.fingerprint.firmwarePath`.

Once booted, deploy over Wi-Fi (SSH port 4440) or USB:

```
nixos-rebuild switch --flake .#<host> --target-host <user>@<ip> --use-remote-sudo
```

A kernel change requires a reboot to take effect; the root is LUKS, so the
initrd stops for a passphrase.

## What this port adds

On top of what mainline provides. Paths are relative to the repository root.

### Kernel (`pkgs/linux-kernel/fairphone-fp5/`)

| File | Purpose |
| --- | --- |
| `default.nix` | Kernel derivation: applies the patches below and sets the board `structuredExtraConfig` (camera, audio, NFC, TEE/QSEECOM, fingerprint, LUKS) |
| `fairphone-fp5-board-support.patch` | Board device tree, rear-camera (imx858) wiring and driver, board audio — imported from sc7280-mainline |
| `fp5-audio.dtsi`, `fp5-camera.dtsi` | Device-tree fragments referenced by the board-support patch |
| `imx858.c`, `imx858-kconfig` | Rear ultrawide camera sensor driver |
| `aw88261-and-q6afe-fixes.patch` | Speaker amp (aw88261) FROMLIST fixes + q6afe LPASS clock-vote fix; without them the speakers stay silent |
| `adc-tm5-processed-read.patch` | Fixes `adc_tm5_get_temp()` returning `-EINVAL` after the `iio_read_channel_processed()` convention change; restores the 8 PMIC thermal zones |
| `hci-qca-drop-unused-event.patch` | WCN6750 sends the baudrate-change complete event asynchronously; drops the spurious event so Bluetooth registers |
| `ptn36502-redriver-startup-delay.patch` | Gives the USB-C redriver rail settling time so DP/display probes reliably |
| `st21nfcd-nfc-driver.patch` | New `st21nfcd` raw-NCI I²C driver (the ST54-generation chip speaks NCI without NDLC framing, so `st-nci` cannot attach) + its DT node on `i2c9` |
| `tee-qseecom-driver.patch` | QSEECOM TEE driver (`drivers/tee/qseecom`) exposing legacy command-interface trusted applications through `/dev/tee*` |
| `tee-qseecom-align-response.patch`, `tee-qseecom-request-writeback.patch` | QSEECOM response-buffer fixes the fingerprint application needs |
| `qcom-scm-qseecom-fp5-allowlist.patch` | Adds `fairphone,fp5` to the SCM QSEECOM allowlist so the interface binds |
| `misc-focaltech-fp-driver.patch` | `focaltech-fp` misc driver owning the sensor's reset/power/interrupt GPIOs and exposing `/dev/focaltech_fp` |
| `dts-fp5-fingerprint-sensor.patch` | Fingerprint DT node + pinctrl states |

### SoC / device modules (`modules/nixos/vanilla-mobile/soc/qcm6490/`)

| File | Purpose |
| --- | --- |
| `default.nix` | qcm6490 module: options `audio`/`modem`/`sensors`/`nfc`/`fingerprint`; wires pd-mapper, hexagonrpcd, the sensor stack, `/persist`, neard, ffsupplicant, focal32-load, fprintd and PAM |
| `fairphone-fp5.nix` | Device definition: partitions, firmware, U-Boot, accel mount matrix, mutter overlay, enables the qcm6490 SoC + NFC |
| `mutter-portrait-autorotate.patch` | Backport of the upstream mutter fix for a portrait device with no tablet-mode switch, enabling native auto-rotation |
| `iio-sensor-proxy-wait-for-hotplug.patch` | Keeps iio-sensor-proxy alive when no SSC sensor exists at startup |
| `fp5-ucm/` | ALSA UCM profile (speaker, mic, DP) |

### Packages (`pkgs/`)

| File | Purpose |
| --- | --- |
| `fairphone-fp5-firmware/` | Device firmware (DSP, modem, GPU, etc.) |
| `pd-mapper/` | Publishes the DSP protection-domain maps over QRTR; without it service-PD sensors never produce data |
| `hexagonrpc/` | hexagonrpcd (ADSP FastRPC) with a hexagonfs write-support patch so the SSC can write its sensor registry back to `/persist` |
| `pil-squasher/` | Assembles split firmware into `.mbn` images |
| `focal32-firmware/extract-from-factory.sh` | Extracts the fingerprint trusted application from a factory zip; the image itself is user-provided via `fingerprint.firmwarePath` |
| `ftharness/` | Client for the fingerprint trusted application over the QSEECOM TEE driver (load, init, command) |
| `ffsupplicant/` | Serves the trusted application's RPMB + gpfile secure-storage listeners |
| `libfprint/` | libfprint with the FocalTech-QSEE driver, so fprintd can see the sensor |

## Hardware support

Confirmed = verified working on hardware.

| Subsystem | Confirmed | Notes |
| --- | :---: | --- |
| Display + backlight | yes | Requires `deferred_probe_timeout=-1` |
| GPU (Adreno 660) | yes | |
| Touchscreen (Goodix Berlin) | yes | |
| Wi-Fi (ath11k WCN6750) | yes | On AHB, not PCI |
| Bluetooth (WCN6750) | yes | Needs `hci-qca-drop-unused-event`; wake-on-BT masked |
| Battery + charging | yes | |
| Suspend / resume | yes | Deep sleep; BT wake interrupt masked |
| Storage (LUKS Btrfs + `/persist`) | yes | |
| Accelerometer + auto-rotation | yes | Native GNOME/mutter auto-rotation |
| Ambient light sensor | yes | |
| Proximity sensor | yes | |
| Speakers | yes | Needs `aw88261-and-q6afe-fixes` |
| Microphone | yes | |
| Haptics (aw86927) | yes | |
| Rear ultrawide camera (imx858) | yes | With autofocus (dw9719) |
| Front camera (s5kjn1) | yes | |
| Camera flash LED | yes | |
| Thermal (8 PMIC zones) | yes | Needs `adc-tm5-processed-read` |
| NFC (ST21NFC) | yes | `st21nfcd` driver + neard; tag reading |
| USB-C DisplayPort out | yes | Single head; no MST |
| USB gadget (ACM / NCM) | yes | |
| A/B slot handling | yes | `qbootctl -m` each boot |
| GNSS/GPS | yes | Position fix via ModemManager (Qualcomm `PQWP2`); exposed to the desktop through geoclue |
| Modem (voice/SMS/data) | partial | Registers; calls need q6voiced card/device numbers |
| Fingerprint (FocalTech FT9362) | yes | Enroll, match and PAM unlock via the TrustZone application (focal32) over QSEECOM |
| Main rear camera (IMX800) | no | No driver on any mainline OS |
| NFC card emulation / secure element | no | Not wired |
