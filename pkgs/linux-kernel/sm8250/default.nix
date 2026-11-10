{
  lib,
  pkgs,
  ...
}:

(pkgs.linuxKernel.manualConfig {
  version = "7.3.0";

  src = pkgs.fetchurl {
    url = "https://gitlab.nura.eco/Frieder.Hannenheim/sm-8250-mainline/-/archive/240c4e0ec544304eb8be8a2d75ac67200de8e4f8/sm-8250-mainline-240c4e0ec544304eb8be8a2d75ac67200de8e4f8.tar.gz";
    hash = "sha256-4+8v/XZfq2f8Buxws01FixO5a7HfEs6DEXbn/SnfCZY=";
  };

  modDirVersion = lib.versions.pad 3 "7.3.0";
  configfile = ./config-postmarketos-qcom-sm8250.aarch64;

  allowImportFromDerivation = false;

}).overrideAttrs (old: {
  patches = (old.patches or []) ++ [
    ./patches/aw8695-bitfield.patch
  ];



  postInstall = (old.postInstall or "") + ''
    mkdir -p $modules/lib/modules/"$version"
    touch $modules/lib/modules/"$version"/modules.order
    touch $modules/lib/modules/"$version"/modules.builtin

    rm -f $out/System.map
  '';

  passthru = (old.passthru or {}) // {
    isModular = false;
    features = {
      isModular = false;
      efiBootStub = true;
    };
  };
})
