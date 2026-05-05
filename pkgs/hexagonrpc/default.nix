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
  ];

  postPatch = (prevAttrs.postPatch or "") + ''
    substituteInPlace hexagonrpcd/rpcd.c --replace-fail '/usr/share/qcom' '/run/current-system/sw/share/qcom'
  '';
})
