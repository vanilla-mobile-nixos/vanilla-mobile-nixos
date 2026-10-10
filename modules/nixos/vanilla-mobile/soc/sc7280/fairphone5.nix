self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.device.fairphone5;

  ucm = "${self.packages.alsa-ucm-conf-sc7280}/share/alsa";

  # Points /run/alsa-ucm2 at the DisplayPort tree while a DP sink advertising
  # audio is connected, then makes PipeWire re-probe the card. Re-announcing the
  # card to udev keeps clients connected; restarting WirePlumber wedges them and
  # leaks ADSP buffers.
  dpAudioSwitch = pkgs.writeShellScript "fp5-dp-audio-switch" ''
    set -u
    conn=/sys/class/drm/card0-DP-1
    eld=/proc/asound/card0/eld#4
    tree=${ucm}/ucm2

    # udev fires in bursts during alt-mode negotiation, and the link may only
    # train (and the ELD appear) seconds after the last event. So watch for
    # ~30s: DP wins once the ELD lists audio, no-DP only after the connector
    # stays disconnected for ~5s, and a video-only sink times out to no-DP.
    down=0
    for _ in $(seq 60); do
      if [ "$(cat $conn/status 2>/dev/null || true)" = "connected" ]; then
        down=0
        if grep -qE '^sad_count[[:space:]]+[1-9]' "$eld" 2>/dev/null; then
          tree=${ucm}/ucm2-dp
          break
        fi
      else
        down=$((down + 1))
        [ "$down" -ge 10 ] && break
      fi
      sleep 0.5
    done

    if [ "$(readlink /run/alsa-ucm2 || true)" = "$tree" ]; then
      exit 0
    fi

    # Checked through PipeWire, because test-opening the PCM here would race
    # PipeWire and leak ADSP buffers.
    have_alsa_sink() {
      for rt in /run/user/*; do
        [ -S "$rt/pipewire-0" ] || continue
        if XDG_RUNTIME_DIR="$rt" pw-dump 2>/dev/null | grep -q '"alsa_output'; then
          return 0
        fi
      done
      return 1
    }

    reprobe() {
      ln -sfnT "$1" /run/alsa-ucm2
      udevadm trigger --action=remove /sys/class/sound/card0
      sleep 2
      udevadm trigger --action=add /sys/class/sound/card0
      sleep 5
      have_alsa_sink
    }

    # A re-probe while the DP link is still settling can come up with no sink
    # at all, and nothing retries it.
    for _ in 1 2 3; do
      reprobe "$tree" && exit 0
    done

    # Fall back to the speaker rather than leaving only a dummy output.
    if [ "$tree" != "${ucm}/ucm2" ]; then
      reprobe ${ucm}/ucm2
    fi
  '';

  fingerprintConfig = pkgs.writeText "ff_config.json" (builtins.toJSON cfg.fingerprint.settings);
in
{
  options.vanilla-mobile.device.fairphone5 = {
    enable = lib.mkEnableOption "Fairphone 5 (fairphone-fp5)";

    fingerprint = {
      enable = lib.mkEnableOption ''
        the fingerprint sensor through fprintd. Needs the unfree
        `focal32-firmware`, which is extracted from the stock firmware'';

      settings = lib.mkOption {
        type = with lib.types; attrsOf (attrsOf anything);
        # Most of the trusted application's own defaults are zero, which
        # breaks it.
        default = {
          driver.spi_bus_num = 14;
          device.spi_default_bps = 2000000;
          # Otherwise the probe gives up before reaching the right chip.
          device.preferred_device_id = "0x9391";

          # Otherwise enrolment needs a token signed by Android's Gatekeeper.
          trustlet.enable_trusted_enrollment = false;

          common.image_processing_cols = 36;
          common.image_processing_rows = 144;
          common.max_enrolling_fingers = 5;
          common.max_enrolling_samples = 12;

          algorithm.min_enrolling_quality_threshold = 30;
          algorithm.min_enrolling_coverage_threshold = 30;
          algorithm.min_identify_quality_threshold = 30;
          algorithm.min_identify_coverage_threshold = 30;
        };
        description = ''
          Configuration for the fingerprint trusted application, written to
          `/etc/focaltech/ff_config.json`.

          `common.max_enrolling_samples` decides how forgiving unlocking is.
          Enrolment can never finish if it's set too high (16 is known to be).
          It has to match `ENROLL_STAGES` in the libfprint driver.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        warnings =
          if !config.boot.loader.systemd-boot.enable then
            [
              ''
                systemd-boot is disabled. fairphone5 has currently only
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
            imageSectorSize = 4096;
            firmware = self.packages.fairphone5-firmware;
            uboot = self.packages.ubootPackages.fairphone-fp5-boot-image;
          };
          soc.sc7280.enable = true;
        };

        boot.initrd = {
          # Based on
          # <https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/testing/device-fairphone-fp5/modules-initfs>
          availableKernelModules = [
            "fsa4480"
            "goodix_berlin_core"
            "goodix_berlin_spi"
            "msm"
            "panel-raydium-rm692e5"
            "ptn36502"
            "spi-geni-qcom"
            "loop"
          ];

          # The NixOS image is a GPT disk image flashed inside the `userdata`
          # partition, the same way U-Boot maps it. Linux doesn't scan nested
          # partition tables, so expose it as a partitioned loop device.
          systemd.initrdBin = [ pkgs.util-linux ];
          services.udev.rules = ''
            SUBSYSTEM=="block", ACTION=="add", ENV{ID_PART_ENTRY_NAME}=="userdata", RUN+="${pkgs.util-linux}/bin/losetup --partscan --find --nooverlap --sector-size ${toString config.vanilla-mobile.deviceInfo.imageSectorSize} --loop-ref userdata /dev/%k"
          '';
        };

        # Otherwise the bootloader eventually marks the A/B slot as unbootable.
        systemd.services.qbootctl-mark-boot-successful = {
          description = "Mark current A/B slot as successfully booted";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe pkgs.qbootctl} -m";
          };
        };

        # See <https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/testing/device-fairphone-fp5/81-libssc-fairphone-fp5.rules>.
        services.udev.extraRules = ''
          SUBSYSTEM=="misc", KERNEL=="fastrpc-*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, -1, 0; 0, 0, -1"
        '';

        # Camera tuning for libcamera's soft ISP, for PipeWire and for apps using
        # libcamera directly.
        environment.sessionVariables.LIBCAMERA_IPA_CONFIG_PATH = "${self.packages.fairphone5-libcamera-tuning
        }";
        systemd.user.services.pipewire.environment.LIBCAMERA_IPA_CONFIG_PATH =
          "${self.packages.fairphone5-libcamera-tuning}";
        systemd.user.services.wireplumber.environment.LIBCAMERA_IPA_CONFIG_PATH =
          "${self.packages.fairphone5-libcamera-tuning}";
      }
      # DisplayPort audio
      (lib.mkIf config.vanilla-mobile.soc.sc7280.audio.enable {
        environment.variables.ALSA_CONFIG_UCM2 = lib.mkForce "/run/alsa-ucm2";
        systemd.tmpfiles.rules = [ "L /run/alsa-ucm2 - - - - ${ucm}/ucm2" ];

        services.udev.extraRules = ''
          ACTION=="change", SUBSYSTEM=="drm", ENV{DEVNAME}=="/dev/dri/card0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="fp5-dp-audio-switch.service"
        '';

        systemd.services.fp5-dp-audio-switch = {
          description = "Select ALSA UCM tree for DisplayPort audio";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-tmpfiles-setup.service" ];
          path = [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.systemd
            config.services.pipewire.package
          ];
          # Hotplug events arrive in bursts, and the last one is the one that matters.
          startLimitIntervalSec = 0;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = dpAudioSwitch;
          };
        };
      })
      # Fingerprint
      (lib.mkIf cfg.fingerprint.enable {
        boot.kernelModules = [ "qseecomtee" ];
        hardware.firmware = [ self.packages.focal32-firmware ];
        environment.etc."focaltech/ff_config.json".source = fingerprintConfig;
        environment.systemPackages = [ self.packages.fp5-fingerprint-tools ];

        services.udev.extraRules = ''
          SUBSYSTEM=="tee", KERNEL=="tee[0-9]*", GROUP="tee", MODE="0660"
        '';
        users.groups.tee = { };

        services.fprintd = {
          enable = true;
          package = pkgs.fprintd.override { libfprint = self.packages.libfprint-focaltech; };
        };
        # The sensor isn't on any bus fprintd's unit allows.
        systemd.services.fprintd.serviceConfig.DeviceAllow = [
          "/dev/focaltech_fp rw"
          "char-tee rw"
        ];

        systemd.services = {
          # Serves the secure storage (RPMB and the GP file service) the trusted
          # application keeps its templates in.
          ffsupplicant = {
            description = "QSEECOM listener supplicant (fingerprint secure storage)";
            wantedBy = [ "multi-user.target" ];
            after = [ "systemd-udev-settle.service" ];
            serviceConfig = {
              ExecStart = "${self.packages.fp5-fingerprint-tools}/bin/ffsupplicant --store /var/lib/ffsupplicant --listener 8192 --listener 28672";
              Restart = "always";
              RestartSec = "1";
              StateDirectory = "ffsupplicant";
              StateDirectoryMode = "0700";
            };
          };

          # The trusted application is unloaded as soon as the session that
          # loaded it closes, so hold it open here for fprintd to attach to.
          focal32-load = {
            description = "Hold the fingerprint trusted application loaded";
            wantedBy = [ "multi-user.target" ];
            after = [
              "systemd-udev-settle.service"
              "ffsupplicant.service"
            ];
            wants = [ "ffsupplicant.service" ];
            before = [ "fprintd.service" ];
            serviceConfig = {
              ExecStart = "${self.packages.fp5-fingerprint-tools}/bin/ftharness load --app focal32";
              Restart = "always";
              RestartSec = "1";
              StandardInput = "null";
            };
          };
        };
      })
    ]
  );

  meta.maintainers = [ lib.maintainers.marcusramberg ];
}
