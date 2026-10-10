# How to update:
# - Rebase `marcus/fp5-7.2.y` in <https://github.com/marcusramberg/linux-mainline>
#   onto the new `sc7280-mainline` tag, dropping any patches that have been merged.
#   The QSEECOM TEE driver comes from <https://github.com/wrobelda/linux/tree/qcom-qseecom-tee>.
# - Bump `version`, `rev` and the pmaports commit of the base config.
{
  lib,
  fetchFromGitHub,
  linuxKernel,
  runCommand,
  stdenv,
  # From `boot.kernelPatches` via `kernel.override`. Must be passed explicitly,
  # callPackage would fill in `pkgs.kernelPatches`.
  kernelPatches ? [ ],
  ...
}:
let
  version = "7.2.9";

  # Built from the postmarketOS config instead of the NixOS one. Evaluated at
  # eval time, so the passthru `config` below doesn't need IFD.
  pmosConfig = builtins.fetchurl {
    url = "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/c9dbdc23ae775aa5cea8b857c123f1696c04528f/device/community/linux-postmarketos-qcom-sc7280/config-postmarketos-qcom-sc7280.aarch64";
    sha256 = "1vjffmn4wx6b6yxp7cn80qpzm744n8h5wci5xwxrpf5f17rq9w87";
  };

  extraConfig = {
    # NixOS asserts this is enabled.
    DMIID = "y";
    # A built-in legacy gadget driver claims the UDC at boot, and every configfs
    # gadget then fails to bind with -EBUSY.
    U_SERIAL_CONSOLE = "y";
    USB_G_SERIAL = "m";
    # NixOS firewall.
    NETFILTER_XT_MATCH_PKTTYPE = "m";
    NETFILTER_XT_MATCH_LIMIT = "m";
    NETFILTER_XT_MATCH_RECENT = "m";
    NETFILTER_XT_MATCH_STATE = "m";
    NETFILTER_XT_TARGET_LOG = "m";
    NETFILTER_XT_TARGET_CONNMARK = "m";
    NETFILTER_XT_MATCH_CONNMARK = "m";
    NFT_FIB = "y";
    NFT_FIB_INET = "y";
    WIREGUARD = "m";
    # Waydroid.
    ANDROID_BINDERFS = "y";
    TYPEC_DP_ALTMODE = "y";
    # The CLF is a plain NCI controller, driven by the st21nfc-nci patch.
    NFC = "m";
    NFC_NCI = "m";
    NFC_ST21NFC_NCI = "m";
    # systemd-boot under U-Boot's UEFI environment.
    EFI = "y";
    EFI_STUB = "y";
    EFI_ZBOOT = "y";
    # camss only registers subdevs once every sensor in the DT has bound.
    VIDEO_IMX800 = "m";
    # Fingerprint sensor.
    TEE_QSEECOM = "m";
    MISC_FOCALTECH_FP = "m";
  }
  // lib.filterAttrs (_: v: v != null) (
    lib.mapAttrs (_: v: v.tristate or v.freeform) (
      lib.mergeAttrsList (map (p: p.structuredExtraConfig or { }) kernelPatches)
    )
  );

  configfile = runCommand "linux-sc7280-config" { } ''
    cat ${pmosConfig} > $out
    cat >> $out <<'EOF'
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "CONFIG_${name}=${value}") extraConfig
    )}
    EOF
  '';

  config =
    let
      parseLine =
        line:
        let
          m = builtins.match "(CONFIG_[^=]+)=([ym])" line;
        in
        lib.optional (m != null) (lib.nameValuePair (lib.elemAt m 0) (lib.elemAt m 1));
    in
    lib.listToAttrs (lib.concatMap parseLine (lib.splitString "\n" (builtins.readFile pmosConfig)))
    // lib.mapAttrs' (name: lib.nameValuePair "CONFIG_${name}") extraConfig;
in
linuxKernel.manualConfig {
  inherit
    lib
    version
    configfile
    config
    ;
  modDirVersion = version;

  src = fetchFromGitHub {
    # `sc7280-mainline` plus Fairphone 5 fixes.
    owner = "sc7280-mainline";
    repo = "linux";
    tag = "v7.2.9-sc7280";
    name = "linux-sc7280-src";
    hash = "sha256-hhrOL2GrReoIY0w392S6Cc7RAnPEE3kHUKfe8HchWso=";
  };

  kernelPatches = import ./kernel-patches ++ kernelPatches;

  # manualConfig doesn't default this like generic.nix does. systemd-repart
  # asserts it.
  features.efiBootStub = true;

  # Needs to match `system.boot.loader.kernelFile`.
  target = "vmlinuz.efi";
  stdenv = stdenv.override {
    hostPlatform = stdenv.hostPlatform // {
      linux-kernel = stdenv.hostPlatform.linux-kernel // {
        target = "vmlinuz.efi";
        installTarget = "zinstall";
      };
    };
  };

  extraMeta.platforms = [ "aarch64-linux" ];
}
