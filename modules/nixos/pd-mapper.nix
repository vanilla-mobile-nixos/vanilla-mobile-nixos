self:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.pd-mapper;
in
{
  options.services.pd-mapper = {
    enable = lib.mkEnableOption "Qualcomm protection domain mapper";
    package = lib.mkPackageOption self.packages "pd-mapper" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.pd-mapper = {
      description = "Qualcomm protection domain mapper";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        RuntimeDirectory = "pd-mapper";
        # pd-mapper does not scan a flat directory. For each remoteproc it
        # reads /sys/class/remoteproc/*/firmware, takes the dirname of that
        # value -- qcom/qcm6490/fairphone5 here -- and looks for .jsn files
        # under <base>/<that relative path>. So the layout has to be mirrored,
        # not flattened.
        #
        # It also reads the maps straight off the filesystem, while this option
        # compresses firmware, so what is on disk is adspr.jsn.zst and friends.
        # The kernel decompresses those transparently; a userspace reader does
        # not, and pd-mapper reports "no pd maps available" and exits. Stage
        # decompressed copies at the same relative paths, into the directory
        # the package is patched to look in.
        ExecStartPre = [
          (pkgs.writeShellScript "pd-mapper-maps" ''
            set -eu
            fw=/run/current-system/firmware
            staging=$(mktemp -d)
            trap 'rm -rf "$staging"' EXIT

            # If this runs before the remoteprocs register, the staging below
            # finds no firmware attributes and the daemon exits "no pd maps
            # available"; Restart=always then retries until they appear. No
            # explicit wait is needed (and there is no stable systemd unit for
            # the remoteproc to order against -- its .device name embeds the
            # SoC address and enumeration index).

            # Gather every map, decompressed, keyed by bare name.
            cd "$fw"
            find . \( -name '*.jsn' -o -name '*.jsn.zst' \) | while read -r f; do
              rel=''${f#./}
              base=$(basename "$rel"); base=''${base%.zst}
              case "$rel" in
                *.zst) ${lib.getExe pkgs.zstd} -dqf "$fw/$rel" -o "$staging/$base" ;;
                *)     cp -f "$fw/$rel" "$staging/$base" ;;
              esac
            done

            # Put them exactly where pd-mapper will look. It reads each
            # remoteproc's firmware attribute and searches the dirname of that
            # value, so derive the layout from the same source rather than
            # hardcoding qcom/<soc>/<board>.
            for d in /sys/class/remoteproc/*/; do
              [ -r "$d/firmware" ] || continue
              rel=$(dirname "$(cat "$d/firmware")")
              [ "$rel" = "." ] && continue
              mkdir -p "/run/pd-mapper/$rel"
              cp -f "$staging"/*.jsn "/run/pd-mapper/$rel/" 2>/dev/null || true
            done

            # Where the package is patched to read its base path from.
            echo /run/pd-mapper > /run/pd-mapper/.firmware-path
          '')
        ];
        ExecStart = lib.getExe cfg.package;
        Restart = "always";
        RestartSec = "5s";
        # Talks to the DSPs over QRTR.
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_NETLINK"
          "AF_QIPCRTR"
        ];
      };
    };
  };
}
