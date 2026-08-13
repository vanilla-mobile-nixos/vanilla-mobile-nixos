{
  hexagonrpc,
  fetchpatch2,
}:
hexagonrpc.overrideAttrs (prevAttrs: {
  patches = (prevAttrs.patches or [ ]) ++ [
    (fetchpatch2 {
      name = "add-systemd-services.patch";
      url = "https://github.com/linux-msm/hexagonrpc/commit/c4109b45023f7dcc5ef20f68b9bebffc6736da7b.patch?full_index=1";
      hash = "sha256-nrVzJ8wjNXTFKgCdiuaPKal31oX4Z0cwGlE9+fe8DZw=";
    })
    # hexagonfs is read-only upstream: every open for write from the DSP is
    # refused with AEE_EUNSUPPORTED. The ADSP sensor process needs to write
    # back its registry (temp.json + rename over the target, and
    # sns_reg_version) under /mnt/vendor/persist/sensors; on this port those
    # writes were denied at ~48/s for the first ~20s of every first attach
    # and the registry write-back has never once succeeded. This implements
    # fopen_with_env "w"/"a", fwrite, fsync, fremove and frename (extension
    # method 33 behind message ID 31), backed by the parent directory's real
    # fd, so only physically-mapped writable directories (the /persist bind
    # mount) accept writes -- the nix store stays read-only at the VFS level.
    ./hexagonfs-write-support.patch
  ];

  postPatch = (prevAttrs.postPatch or "") + ''
    substituteInPlace hexagonrpcd/rpcd.c --replace-fail '/usr/share/qcom' '/run/current-system/sw/share/qcom'
  '';
})
