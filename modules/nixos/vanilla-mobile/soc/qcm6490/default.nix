self: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.vanilla-mobile.soc.qcm6490;
in {
  imports = [
    (import ./fairphone-fp5.nix self)
  ];

  options.vanilla-mobile.soc.qcm6490 = {
    enable = lib.mkEnableOption "qcm6490";

    audio.enable = lib.mkEnableOption "audio";
    modem.enable = lib.mkEnableOption "modem";
    sensors.enable = lib.mkEnableOption "sensors";
    nfc.enable = lib.mkEnableOption "NFC (neard over the st21nfcd NCI driver)";

    fingerprint = {
      enable = lib.mkEnableOption "fingerprint (focal32 TrustZone app over QSEECOM)";

      firmwarePath = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression "./secrets/focal32";
        description = ''
          Path to a directory holding the fingerprint trusted-application
          image in split form: `focal32.mdt` plus `focal32.b00` ...
          `focal32.b07`.

          The image is proprietary and specific to the device it was signed
          for, so it is deliberately not shipped with this flake. Extract it
          from your own device's factory image with
          `pkgs/focal32-firmware/extract-from-factory.sh` and provide the path
          from your own configuration. Under flakes the path must live inside
          your configuration's own source tree.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        vanilla-mobile.soc.qcm6490 = {
          audio.enable = lib.mkDefault true;
          modem.enable = lib.mkDefault true;
          sensors.enable = lib.mkDefault true;
        };

        vanilla-mobile.enable = true;

        nixpkgs.hostPlatform = "aarch64-linux";

        # Some firmware from `linux-firmware` is required.
        hardware.enableRedistributableFirmware = true;

        # Link firmware `/share` into environment for hexagonrpcd.
        environment.systemPackages = [config.vanilla-mobile.deviceInfo.firmware];

        vanilla-mobile.uboot.enable = true;
        boot = {
          # U-Boot provides UEFI, so this is an ordinary systemd-boot setup.
          loader = {
            systemd-boot.enable = lib.mkDefault true;
            efi.canTouchEfiVariables = lib.mkDefault false;
          };

          kernelPackages = lib.mkForce (
            config.vanilla-mobile.installer.crossPkgs.linuxPackagesFor
            config.vanilla-mobile.installer.vanillaMobileCrossPkgs.linuxKernels.linux_fairphone_fp5
          );

          kernelParams = [
            "console=tty0"
            "typec_ucsi.disable_upm=1"
          ];

          initrd = {
            # Disable default modules, some of which do not exist in our kernel.
            includeDefaultModules = false;
            availableKernelModules = [
              "sd_mod"
            ];
            kernelModules = [
              "dm_mod"
            ];

            systemd.tpm2.enable = false;
          };
        };

        hardware.bluetooth.enable = lib.mkDefault true;
        services.bootmac = {
          enable = true;
          bluetooth.enable = true;
        };

        # No writable RTC.
        services.swclock-offset.enable = true;

        # The Bluetooth UART's RX-pin wake IRQ (tlmm gpio31, IRQ 113) aborts
        # every deep suspend ("Wakeup pending. Abort CPU freeze") though
        # nothing drives the line. Disabling its wakeup makes suspend hold and
        # resume on the RTC alarm and power key; the cost is no wake-on-BT.
        # This masks rather than fixes -- see FINDINGS for the ruled-out
        # causes. Matched on bind too: power/wakeup only exists once
        # qcom_geni_serial has probed, after the add event fires.
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="platform", KERNEL=="a600000.usb", ATTR{power/control}="auto"
          ACTION=="add", SUBSYSTEM=="platform", KERNEL=="ae00000.display-subsystem", ATTR{power/control}="auto"
          ACTION=="add|bind", SUBSYSTEM=="platform", KERNEL=="99c000.serial", ATTR{power/wakeup}="disabled"
        '';

        # No swap to hibernate into; suspend (s2idle/deep) is used instead.
        systemd.sleep.settings.Sleep = {
          AllowHibernation = lib.mkDefault "no";
          AllowSuspendThenHibernate = lib.mkDefault "no";
          AllowHybridSleep = lib.mkDefault "no";
        };

        # Qualcomm A/B: the bootloader decrements the active slot's retry
        # counter each boot and only resets it when userspace marks the slot
        # good; without this the slot reaches unbootable.
        systemd.services.qbootctl-mark-successful = {
          description = "Mark the current A/B slot as successfully booted";
          wantedBy = ["multi-user.target"];
          after = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.qbootctl}/bin/qbootctl -m";
          };
        };
      }
      # Audio
      (lib.mkIf cfg.audio.enable {
        # Only tested with PipeWire.
        services.pipewire = {
          enable = lib.mkDefault true;
          alsa.enable = lib.mkDefault true;
          pulse.enable = lib.mkDefault true;
        };
        security.rtkit.enable = lib.mkDefault true;

        # q6voiced is not enabled here: it needs per-device card/device numbers
        # read from `alsactl info` on the running phone, so each device module
        # turns it on once those are known.
      })
      # Modem
      (lib.mkIf cfg.modem.enable {
        services.rmtfs.enable = true;
        services.tqftpserv.enable = true;
        # The DSPs fetch "readwrite/..." files over TFTP for their runtime
        # state. Stock tqftpserv serves those from a tmp directory, so that
        # state evaporates every boot; the SSC in particular initializes
        # flakily without it. Point it at the vendor /persist partition,
        # which is what the firmware expects to be backing this.
        nixpkgs.overlays = [
          (final: prev: {
            tqftpserv = prev.tqftpserv.overrideAttrs (old: {
              postPatch =
                (old.postPatch or "")
                + ''
                  sed -i 's|#define TQFTPSERV_TMP.*|#define TQFTPSERV_TMP "/persist"|' translate.c
                '';
            });
          })
        ];
        systemd.tmpfiles.rules = [
          "L+ /readwrite - - - - /persist"
        ];
        # Publishes the DSP protection-domain maps. Without it a DSP's root PD
        # still answers -- sensors can be discovered and their attributes read
        # -- while anything in a service PD never produces data.
        services.pd-mapper.enable = true;
        services.msm-modem-uim-selection.enable = true;

        networking.modemmanager.enable = true;

        # rpmsg_wwan_ctrl exposes the modem's AT ports; ModemManager probing
        # them deadlocks in the kernel (wwan_remove_port on an owned mutex),
        # wedging ModemManager until reboot. It reaches the modem over QMI/QRTR
        # anyway, so dropping the AT ports removes the trigger, not the
        # transport.
        boot.blacklistedKernelModules = ["rpmsg_wwan_ctrl"];

        # GNSS reaches the OS through ModemManager's GPS. geoclue exposes it to
        # the desktop (GNOME location services); enableModemGPS is the GPS
        # source, enable3G gives a coarse cell-tower fallback.
        services.geoclue2 = {
          enable = true;
          enableModemGPS = true;
          enable3G = true;
        };

        # Nothing stops the modem remoteproc at shutdown, so rmtfs gets
        # killed while the modem still issues storage requests against it
        # and wedges in an uninterruptible kernel sleep -- it survives
        # SIGKILL and shutdown crawls through ~4.5 min of escalating
        # timeouts. Started after rmtfs, so its ExecStop runs before
        # rmtfs's stop and shuts the modem down first.
        systemd.services.qcom-modem-shutdown = {
          description = "Stop the modem remoteproc before rmtfs stops";
          wantedBy = ["multi-user.target"];
          after = ["rmtfs.service"];
          unitConfig.DefaultDependencies = true;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.coreutils}/bin/true";
            ExecStop = pkgs.writeShellScript "qcom-modem-shutdown" ''
              for r in /sys/class/remoteproc/remoteproc*; do
                case "$(cat "$r/firmware" 2>/dev/null)" in
                  *modem*)
                    echo stop > "$r/state" 2>/dev/null || true
                    ;;
                esac
              done
            '';
          };
        };
      })
      # NFC userspace. The kernel st21nfcd driver exposes the controller as
      # nfc0; neard is the daemon that powers the adapter, polls as an
      # initiator, and reads tags' NDEF records onto D-Bus (no GNOME NFC UX
      # exists, so neard + nfctool/D-Bus is the interface). ConstantPoll keeps
      # a discovery loop running so a tag is picked up whenever it enters the
      # field.
      (lib.mkIf cfg.nfc.enable {
        services.neard = {
          enable = true;
          settings.General = {
            ConstantPoll = true;
            DefaultPowered = true;
            ResetOnError = true;
          };
        };
        environment.systemPackages = [pkgs.neard]; # nfctool

        # neard powers the adapter but only starts a poll loop on request (it
        # ships no NDEF agent here, and there is no GNOME NFC UX to register
        # one). This starts the initiator poll loop once neard is up, so a tag
        # presented to the phone is discovered and its NDEF read to D-Bus
        # without any manual busctl poking. ConstantPoll then re-arms the loop
        # after each tag leaves the field.
        systemd.services.neard-poll = {
          description = "Start the neard initiator poll loop";
          wantedBy = ["multi-user.target"];
          after = ["neard.service"];
          wants = ["neard.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # neard is D-Bus activated; the property/method calls bring it up.
            ExecStart = pkgs.writeShellScript "neard-poll" ''
              ${pkgs.systemd}/bin/busctl --system set-property org.neard \
                /org/neard/nfc0 org.neard.Adapter Powered b true || true
              ${pkgs.systemd}/bin/busctl --system call org.neard \
                /org/neard/nfc0 org.neard.Adapter StartPollLoop s Initiator || true
            '';
          };
        };
      })

      # Fingerprint bring-up (go/no-go): load the focal32 TrustZone application
      # over the QSEECOM TEE driver and confirm the device's secure world
      # accepts it. This is not yet a fingerprint stack -- no supplicant,
      # enrollment or matching -- just the reach: the kernel driver
      # (qseecomtee), the device-extracted trusted application in the firmware
      # path, and ftharness to drive the load. The SPI bus is TZ-owned, so
      # there is no normal-world path to the sensor; everything goes through
      # this application.
      (lib.mkIf cfg.fingerprint.enable (
        let
          # The QSEECOM TEE driver loads a trusted application with
          # request_firmware(), asking for <name>.mdt first and then each .bNN
          # segment. The image is user-provided (see fingerprint.firmwarePath);
          # kept in split form here rather than squashed to a single .mbn.
          focal32Firmware = pkgs.runCommandLocal "focal32-firmware" {} ''
            install -Dm644 -t $out/lib/firmware \
              ${cfg.fingerprint.firmwarePath}/focal32.mdt \
              ${cfg.fingerprint.firmwarePath}/focal32.b0[0-7]
          '';
          # The trusted application's configuration, sent as JSON with
          # SYNC_CONFIG before anything else. These are the minimum keys that
          # reach a live sensor, confirmed on hardware: spi_bus_num=14 is the
          # secure SPI instance (QUP1 SE6); preferred_device_id must be a
          # STRING or the probe stalls on ft9601 and returns -11; the image
          # geometry (36x144) and non-zero enrolling caps are required or the
          # application dereferences a zero-sized allocation / refuses every
          # enrollment. enable_trusted_enrollment is off because on it the app
          # demands an Android Gatekeeper token nothing here can produce; the
          # authentication gate moves up to polkit in front of fprintd.
          ffConfig = pkgs.writeText "ff_config.json" (builtins.toJSON {
            driver.spi_bus_num = 14;
            device.spi_default_bps = 2000000;
            device.preferred_device_id = "0x9391";
            trustlet.enable_trusted_enrollment = false;
            common.image_processing_cols = 36;
            common.image_processing_rows = 144;
            common.max_enrolling_fingers = 5;
            common.max_enrolling_samples = 8;
            algorithm.min_enrolling_quality_threshold = 30;
            algorithm.min_enrolling_coverage_threshold = 30;
            algorithm.min_identify_quality_threshold = 30;
            algorithm.min_identify_coverage_threshold = 30;
          });

          # Bring the trusted application up to calibrated + scanning + armed
          # for finger detection. SYNC_CONFIG first (ff_spi_init reads
          # spi_bus_num as it opens the bus); then INIT_SPI, SET_SPI_SPEED,
          # PROBE_DEVICE, INIT_DEVICE, TRUSTLET_INIT, START_SCANNING, and
          # FDT_DOWN_DETECT (scanning alone images but does not watch for a
          # finger; this arms gpio34).
          initSequence = lib.concatStringsSep "," [
            "0x100d@${ffConfig}"
            "0x1006"
            "0x1008:2000000"
            "0x100a:1"
            "0x100b"
            "0x1004"
            "0x1012"
            "0x101f:1"
          ];

          fp5-fp-init = pkgs.writeShellScriptBin "fp5-fp-init" ''
            set -eu
            seq=${lib.escapeShellArg initSequence}
            [ "$#" -gt 0 ] && { seq="$seq,$1"; shift; }
            exec ${lib.getExe pkgs.ftharness} cmd --reset --rsp 0x40000 --seq "$seq" "$@"
          '';
        in {
          assertions = [
            {
              assertion = cfg.fingerprint.firmwarePath != null;
              message = ''
                vanilla-mobile.soc.qcm6490.fingerprint.enable requires
                fingerprint.firmwarePath to point at the device-specific
                focal32 trusted-application image (see the option description).
              '';
            }
          ];

          boot.kernelModules = ["qseecomtee"];
          hardware.firmware = [focal32Firmware];
          environment.systemPackages = [
            pkgs.ftharness
            pkgs.ffsupplicant
            fp5-fp-init
          ];
          environment.etc."focaltech/ff_config.json".source = ffConfig;

          # /dev/teepriv0 (load + listeners) stays root-only; the client device
          # /dev/tee0 is where sessions run.
          services.udev.extraRules = ''
            SUBSYSTEM=="tee", KERNEL=="tee[0-9]*", MODE="0660", GROUP="wheel"
          '';

          # The trusted application blocks on the normal world to answer its
          # secure-storage requests; without this daemon nothing can be
          # enrolled (reads and writes fail with an I/O error). RPMB (8192)
          # carries the storage; the gpfile service (28672) is probed on the
          # way there and must be answered too. The supplicant is not trusted:
          # objects are sealed and authenticated by the secure world before
          # they cross this boundary.
          systemd.services.ffsupplicant = {
            description = "QSEECOM listener supplicant (fingerprint secure storage)";
            wantedBy = ["multi-user.target"];
            after = ["systemd-udev-settle.service"];
            serviceConfig = {
              ExecStart = "${lib.getExe pkgs.ffsupplicant} --store /var/lib/ffsupplicant --listener 8192 --listener 28672";
              Restart = "always";
              RestartSec = "1";
              User = "root";
              StateDirectory = "ffsupplicant";
              StateDirectoryMode = "0700";
            };
          };

          # The trusted application stays loaded only while the session that
          # loaded it is open -- the driver unloads it the moment that closes.
          # So one process loads it and holds it, and fprintd attaches to what
          # it holds (loading it in neither lets ftharness and fprintd
          # coexist). Ordered after the supplicant so the app reaches its
          # storage as soon as it initialises.
          systemd.services.focal32-load = {
            description = "Hold the fingerprint trusted application loaded";
            wantedBy = ["multi-user.target"];
            after = ["systemd-udev-settle.service" "ffsupplicant.service"];
            wants = ["ffsupplicant.service"];
            before = ["fprintd.service"];
            serviceConfig = {
              ExecStart = "${lib.getExe pkgs.ftharness} load --app focal32";
              User = "root";
              Restart = "always";
              RestartSec = "1";
              KillSignal = "SIGTERM";
              StandardInput = "null";
            };
          };

          # fprintd owns enrollment and matching; the libfprint override carries
          # the FocalTech QSEE driver (nixpkgs' own libfprint has no driver
          # that can see this sensor). fprintd's unit whitelists USB/SPI/hidraw
          # readers; this sensor is on none of those, so widen DeviceAllow to
          # the misc node and the TEE client device.
          services.fprintd.enable = true;
          nixpkgs.overlays = [
            (final: prev: {libfprint = self.packages.libfprint-focaltech;})
          ];
          systemd.services.fprintd.serviceConfig.DeviceAllow = [
            "/dev/focaltech_fp rw"
            "char-tee rw"
          ];

          # Fingerprint unlock at the greeter, screen-lock and sudo. The
          # fprintd PAM module is `sufficient`: it is tried first and, on any
          # failure or with no enrolled finger, PAM falls through to the
          # password prompt -- so this cannot lock anyone out. Enroll with
          # `fprintd-enroll` first; until then these are no-ops.
          security.pam.services = {
            login.fprintAuth = lib.mkForce true;
            sudo.fprintAuth = lib.mkForce true;
            gdm-password.fprintAuth = lib.mkForce true;
            gdm-fingerprint.fprintAuth = lib.mkForce true;
          };
        }
      ))

      # Sensors reach the ADSP over Qualcomm's Sensor Core, not as ordinary
      # IIO devices: nothing appears under /sys/bus/iio until the ADSP is up
      # and iio-sensor-proxy is built with the SSC backend.
      (lib.mkIf cfg.sensors.enable {
        services.hexagonrpcd.adsp-sensorspd.enable = true;
        hardware.sensor.iio.enable = true;

        # Vendor partition holding the factory sensor registry; already in the
        # Android layout, so this needs no repartitioning.
        fileSystems."/persist" = {
          device = "/dev/disk/by-partlabel/persist";
          fsType = "ext4";
          options = ["nofail"];
        };

        # /persist's root is owned by the Android "system" gid 1000, which has
        # no NixOS group. Name it so a member can list /persist without root;
        # add users to it from the host config.
        users.groups.persist.gid = lib.mkDefault 1000;

        # ssc-support is a meson feature; left at `auto` it silently drops
        # sensors. The patch keeps the daemon alive when no sensor exists at
        # startup -- SSC sensors only appear once hexagonrpcd has brought the
        # ADSP up, long after it starts.
        nixpkgs.overlays = [
          (final: prev: {
            iio-sensor-proxy = prev.iio-sensor-proxy.overrideAttrs (old: {
              patches =
                (old.patches or [])
                ++ [
                  ./iio-sensor-proxy-wait-for-hotplug.patch
                ];
              buildInputs = (old.buildInputs or []) ++ [final.libssc];
              mesonFlags = (old.mesonFlags or []) ++ ["-Dssc-support=enabled"];
            });
          })
        ];

        # Upstream ships no libssc rules and keeps accel and proximity behind
        # a udev opt-in. Sensor DSPs only: the CDSP carries none.
        services.udev.extraRules = ''
          SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-light ssc-proximity ssc-compass"
          SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-light ssc-proximity ssc-compass"
        '';

        # The ADSP firmware resolves hardcoded absolute paths, so it gets a
        # private root holding the hexagonfs tree. /persist/sensors is bind
        # mounted rather than copied: the firmware writes sns_reg_version.
        systemd.services.hexagonrpcd-adsp-sensorspd = {
          # Bound the upstream Restart=always: each failed attach can leak one
          # of the DSP's ~22 protection-domain slots, and exhausting them
          # wedges the DSP until it is cycled. Stop well short.
          startLimitIntervalSec = 600;
          startLimitBurst = 8;
          # pd-mapper has to have published the ADSP's protection-domain map
          # before the sensor PD can be reached, or the daemon comes up
          # against a subsystem whose service PDs are not addressable yet.
          requires = [
            "persist.mount"
            "pd-mapper.service"
          ];
          after = [
            "persist.mount"
            "pd-mapper.service"
          ];
          serviceConfig = {
            RuntimeDirectory = "hexagon-adsp";
            # The registry carries Android ownership (uid 1000) and its inner
            # directory is 0700, so resolving the registry/registry/../ paths
            # the firmware asks for means traversing a directory fastrpc
            # cannot enter. Group permissions cannot grant this (0700), and
            # chowning would rewrite vendor data, so the daemon keeps its own
            # uid and is given only the capability to bypass the check.
            AmbientCapabilities = ["CAP_DAC_OVERRIDE"];
            CapabilityBoundingSet = ["CAP_DAC_OVERRIDE"];
            ExecStartPre = [
              ("+"
                + pkgs.writeShellScript "hexagonrpcd-adsp-sensorspd-root" ''
                  set -eu
                  root=/run/hexagon-adsp
                  ${pkgs.util-linux}/bin/umount -l "$root/sensors/registry" 2>/dev/null || true
                  ${pkgs.util-linux}/bin/umount -l "$root/mnt/vendor/persist/sensors" 2>/dev/null || true
                  cp -r ${config.vanilla-mobile.deviceInfo.firmware}/lib/firmware/qcom/*/*/hexagonfs/. "$root/"
                  mkdir -p "$root/sys/devices/soc0"
                  for f in family machine revision soc_id hw_platform \
                           platform_subtype platform_subtype_id platform_version; do
                    [ -f "/sys/bus/soc/devices/soc0/$f" ] \
                      && cp "/sys/bus/soc/devices/soc0/$f" "$root/sys/devices/soc0/$f"
                  done
                  # The sensor firmware also looks for its registry config at
                  # this Android path inside the private root.
                  mkdir -p "$root/vendor/etc/sensors"
                  cp ${config.vanilla-mobile.deviceInfo.firmware}/lib/firmware/qcom/*/*/hexagonfs/sensors/sns_reg.conf \
                    "$root/vendor/etc/sensors/sns_reg_config"
                  # The DSP-visible registry directory is the REAL one on
                  # /persist: <dir>/registry/<item> is the factory registry the
                  # firmware reads, and with hexagonrpcd's write support it
                  # writes runtime items back next to it (temp.json renamed
                  # over the target, sns_reg_version) exactly as on Android.
                  # The store copy staged by the cp above only seeds the
                  # mountpoint; it is shadowed by the bind mount.
                  ${pkgs.util-linux}/bin/mount --bind /persist/sensors/registry "$root/sensors/registry"
                '')
            ];
            ExecStart = [
              ""
              "${config.services.hexagonrpcd.package}/bin/hexagonrpcd -f /dev/fastrpc-adsp -d adsp -R /run/hexagon-adsp -s"
            ];
            ExecStopPost = [
              "+-${pkgs.util-linux}/bin/umount -l /run/hexagon-adsp/sensors/registry"
            ];
          };
        };

        # Bound to the daemon rather than started independently: without the
        # ADSP there is nothing for it to find.
        # SSC sensors are not kernel IIO devices; iio-sensor-proxy reaches
        # them over libssc, so nothing hotplugs to activate it on demand.
        systemd.services.iio-sensor-proxy = {
          wantedBy = ["multi-user.target"];
          bindsTo = ["hexagonrpcd-adsp-sensorspd.service"];
          after = ["hexagonrpcd-adsp-sensorspd.service"];
          serviceConfig = {
            Restart = "always";
            RestartSec = "5s";
            RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_QIPCRTR"];
          };
        };

        # hexagonrpcd stops itself on suspend (its fastrpc session is stale
        # after the ADSP resets) and nothing brings it back -- both units are
        # already active under multi-user.target -- so a suspend, even one
        # that aborts before sleep, leaves the sensor stack dead. Restart it.
        systemd.services.hexagonrpcd-adsp-sensorspd-resume = {
          description = "Restore the ADSP sensor stack after resume";
          wants = ["hexagonrpcd-adsp-sensorspd.service"];
          wantedBy = ["suspend.target"];
          after = ["suspend.target"];
          serviceConfig = {
            Type = "oneshot";
            # The ADSP resets across suspend; restarting the stack the instant
            # resume fires attaches before it has re-initialized and the
            # stream stays silently dead. Let it settle first.
            ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
            ExecStart =
              "${config.systemd.package}/bin/systemctl restart"
              + " hexagonrpcd-adsp-sensorspd.service iio-sensor-proxy.service";
          };
        };
      })
    ]
  );
}
