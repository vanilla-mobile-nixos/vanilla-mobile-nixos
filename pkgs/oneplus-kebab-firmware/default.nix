{
  lib,
  stdenvNoCC,
  fetchurl,
  qca-swiss-army-knife,
}:

stdenvNoCC.mkDerivation {

  pname = "oneplus-kebab-firmware";
  version = "1";
  srcs = [
    (fetchurl {
      url = "https://git.sr.ht/~jane400/firmware-oneplus-kebab/archive/d92ee8bfda53cd0e24f4823c45da6e46c6100cf4.tar.gz";
      hash = "sha512-kt2rVS4ZizQIjFaLodb0AOGu7ND5wJSRJxhX6xASNXEUgdqiaINUBCD0jV/1TOlDZYAYkPDht0EMhcWM0AzP5w==";
    })
    (fetchurl {
      url = "https://github.com/pangwalla/oneplus-instantnoodlep-firmware/archive/2dce2681689fcf615198c663555c5a7c7b3650ba/oneplus-instantnoodlep-firmware-2dce2681689fcf615198c663555c5a7c7b3650ba.tar.gz";
      hash = "sha512-woVYBeYyeXf70RntiedgEFhicwCCYMTfgnYiJm9C3DGKv39h94QIWWN3M4zzbAPdELcnm25veYZWnJcP/65y2g==";
    })
  ];

  nativeBuildInputs = [
    qca-swiss-army-knife
  ];
  sourceRoot = ".";
  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;
  dontStrip = true;
  installPhase = ''

          firmwareDir="$out/lib/firmware"
          deviceDir="$firmwareDir/qcom/sm8250/OnePlus/kebab"

          mkdir -p "$firmwareDir/postmarketos"
          mkdir -p "$deviceDir"
          ls
          cd oneplus-instantnoodlep-firmware-*
          for file in bluetooth/*; do
    		    install -Dm644 $file -t "$firmwareDir/postmarketos/qca/"
    		    install -Dm644 $file -t "$firmwareDir/qca/"
    	    done

    	    cd "wlan"
    	    ath11k-bdencoder -c board-2.json
    	    cd ..

          install -Dm644 "wlan/board-2.bin" -t "$firmwareDir/ath11k/QCA6390/hw2.0"
          install -Dm644 "wlan/board-2.bin" \
  "$firmwareDir/ath11k/QCA6390/hw2.0/board2.bin"

          install -Dm644 "wlan/board-2.bin" -t "$firmwareDir/postmarketos/ath11k/QCA6390/hw2.0"

          install -Dm644 "wlan/board-2.bin" \
  "$firmwareDir/postmarketos/ath11k/QCA6390/hw2.0/board2.bin"
    	    install -Dm644 "wlan/amss.bin" -t "$firmwareDir/ath11k/QCA6390/hw2.0"
    	    install -Dm644 "wlan/amss.bin" -t "$firmwareDir/postmarketos/ath11k/QCA6390/hw2.0"

    	    install -Dm644 "wlan/m3.bin" -t "$firmwareDir/ath11k/QCA6390/hw2.0"
    	    install -Dm644 "wlan/m3.bin" -t "$firmwareDir/postmarketos/ath11k/QCA6390/hw2.0/"


          cd ../firmware-oneplus-kebab-*
          for fw in adsp cdsp a650_zap ipa_fws ipa_uc slpi venus; do
            install -Dm644 "$fw.mbn" "$firmwareDir/postmarketos/$fw.mbn"
            install -Dm644 "$fw.mbn" "$deviceDir/$fw.mbn"
          done
  '';

  meta = {
    description = "Firmware for OnePlus 8T";
    homepage = "";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ jedugsem ];
    platforms = lib.platforms.all;
    # Firmware that was originally prefixed with `postmarketos/` needs to overwrite
    # `linux-firmware`.
    priority = 7;
  };
}
