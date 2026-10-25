{
  modemmanager,
  fetchpatch,
}:
# Use-after-free on bearer connect segfaults on qmapmux links; fixed upstream after 1.24.2.
modemmanager.overrideAttrs (prevAttrs: {
  patches = (prevAttrs.patches or [ ]) ++ [
    (fetchpatch {
      url = "https://gitlab.freedesktop.org/mobile-broadband/ModemManager/-/commit/9317cbc4702c7d6283e42a498cd9812e19eeccf3.diff";
      hash = "sha256-xAFZX9LjkKpqDnIxssMkUSKzA02rlufwzNIgHrkt2Aw=";
    })
  ];
})
