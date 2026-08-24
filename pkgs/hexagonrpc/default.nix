{
  hexagonrpc,
}:
hexagonrpc.overrideAttrs (prevAttrs: {
  postPatch = (prevAttrs.postPatch or "") + ''
    substituteInPlace hexagonrpcd/rpcd.c --replace-fail '/usr/share/qcom' '/run/current-system/sw/share/qcom'
  '';
})
