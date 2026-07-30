# Gwyddion 3.x — the GTK3 rewrite, not in nixpkgs (which carries 2.70 only).
#
# Why we want it: Gwyddion 2.x is GTK+2, which has no HiDPI support at all, so
# under niri it runs through XWayland at the raw physical resolution and its
# whole UI ends up half-size on a scale-2 output (making the compositor's
# correctly-sized cursor look enormous by comparison). GTK3 speaks Wayland
# natively and honours the output scale, which sidesteps the problem entirely.
#
# Upstream still calls the 3.x series unstable; 3.11 "Dogfood" (2026-06-25) is
# the release where the developers switched to it for their own AFM work.
# Everything installs under a `3` suffix (binary `gwyddion3`, libs in
# lib/gwyddion3, pkg-config libgwyddion3), so this coexists with pkgs.gwyddion
# and 2.70 stays available as the fallback.
{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  gettext,
  # configure hard-requires a Python 3 interpreter for the build-aux scripts,
  # even though pygwy itself is disabled in 3.11.
  python3,
  wrapGAppsHook3,
  glib,
  gtk3,
  # The 3D view module includes <epoxy/gl.h> directly. gtk3 pulls libepoxy in
  # at link time but not into the include path, so it has to be listed here.
  libepoxy,
  fftw,
  libpng,
  zlib,
  # Optional, all auto-detected by configure. Left on since they only add
  # file-format readers (and the closure is dominated by gtk3 regardless).
  bzip2,
  zstd,
  libzip,
  libwebp,
  openexr,
  cfitsio,
  libxml2,
  json-glib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gwyddion3";
  version = "3.11";

  src = fetchurl {
    url = "mirror://sourceforge/gwyddion/gwyddion-${finalAttrs.version}.tar.xz";
    hash = "sha256-sMStgpudEBUA91tH5Pq1yAVTOKYCw7ofPZj3Lmzhtgo=";
  };

  nativeBuildInputs = [
    pkg-config
    gettext
    python3
    # GTK3 app: wraps the binary with GSettings schemas and the gdk-pixbuf
    # loader cache so icons and the file chooser work outside a GNOME session.
    wrapGAppsHook3
  ];

  buildInputs = [
    glib
    gtk3
    libepoxy
    fftw
    libpng
    zlib
    bzip2
    zstd
    libzip
    libwebp
    openexr
    cfitsio
    libxml2
    json-glib
  ];

  # Upstream bug in 3.11: the 27 sources in modules/synth include "preview.h",
  # which lives one level up in modules/, but modules/synth/Makefile.am only
  # passes -I$(top_srcdir). Neither that nor gcc's "search the including file's
  # own directory" rule reaches modules/preview.h, so the whole synth directory
  # fails to compile. Patch the generated Makefile.in since we don't re-run
  # automake. Drop this once upstream fixes the include path.
  #
  # The second hunk fixes the one thing that is *not* namespaced: both 2.x and
  # 3.x derive their gettext domain from PACKAGE (= "gwyddion"), so both install
  # share/locale/*/LC_MESSAGES/gwyddion.mo and buildEnv refuses to merge them
  # into home.packages. Renaming the domain to "gwyddion3" moves the installed
  # catalogues and the bindtextdomain() call together, so both packages keep
  # their translations. The two substitutions must stay in sync — changing only
  # one silently leaves 3.x untranslated.
  postPatch = ''
    substituteInPlace modules/synth/Makefile.in \
      --replace-fail \
        'AM_CPPFLAGS = -I$(top_srcdir) -DG_LOG_DOMAIN' \
        'AM_CPPFLAGS = -I$(top_srcdir) -I$(top_srcdir)/modules -DG_LOG_DOMAIN'

    substituteInPlace configure \
      --replace-fail 'GETTEXT_PACKAGE=$PACKAGE_TARNAME' 'GETTEXT_PACKAGE=gwyddion3'
    substituteInPlace po/Makevars \
      --replace-fail 'DOMAIN = $(PACKAGE)' 'DOMAIN = gwyddion3'
  '';

  configureFlags = [
    # devel-docs needs gtk-doc 1.32 and only produces API HTML we don't ship.
    "--disable-gtk-doc"
    # pygwy is commented out of configure.ac in 3.11, so introspection has no
    # consumer here — skip it rather than drag in gobject-introspection.
    "--enable-introspection=no"
  ];

  enableParallelBuilding = true;

  meta = {
    homepage = "http://gwyddion.net/";
    description = "Scanning probe microscopy data visualization and analysis (GTK3 development series)";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    mainProgram = "gwyddion3";
  };
})
