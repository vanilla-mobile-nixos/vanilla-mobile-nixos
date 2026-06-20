{
  lib,
  python3Packages,
  fetchFromGitLab,
  just,
  wrapGAppsHook3,
  gobject-introspection,
  libnotify,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "usb-moded-notify";
  version = "0.4.0";
  pyproject = false;

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "usb-moded-notify";
    rev = finalAttrs.version;
    hash = "sha256-/joXgLpm3Pzm0f5A+f3MOwgur4QWw8CvJOh9oWRptZE=";
  };

  nativeBuildInputs = [
    just
    wrapGAppsHook3
    gobject-introspection
  ];

  buildInputs = [ libnotify ];

  dependencies = with python3Packages; [
    dbus-python
    pygobject3
  ];

  env = {
    PREFIX = "";
    DESTDIR = "$out";
  };

  postInstall = ''
    substituteInPlace $out/lib/systemd/user/usb-moded-notify.service \
      --replace-fail "/bin/usb-moded-notify" "$out/bin/usb-moded-notify"
  '';

  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  dontWrapGApps = true;

  meta = {
    description = "Handle usb-moded dialog events/switch modes using desktop notifications";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/usb-moded-notify";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ junestepp ];
    platforms = lib.platforms.linux;
  };
})
