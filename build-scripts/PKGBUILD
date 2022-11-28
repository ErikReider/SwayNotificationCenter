# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync
pkgver=0.7.3
pkgrel=1
pkgdesc="A simple notificaion daemon with a GTK panel for checking previous notifications like other DEs"
_pkgfoldername=SwayNotificationCenter
url="https://github.com/ErikReider/$_pkgfoldername"
arch=(
    'x86_64'
    'aarch64' # ARM v8 64-bit
    'armv7h'  # ARM v7 hardfloat
)
license=(GPL3)
depends=("gtk3" "gtk-layer-shell" "dbus" "glib2" "gobject-introspection" "libgee" "json-glib" "libhandy")
conflicts=("swaync" "swaync-client")
provides=("swaync" "swaync-client")
makedepends=(vala meson git scdoc)
source=("${_pkgfoldername}-${pkgver}.tar.gz::${url}/archive/v${pkgver}.tar.gz")
sha256sums=('c17553ac00e3824ea6c9c2ebf777d9e1c73e0cb46dd663b91eab04c71303ced6')

build() {
    arch-meson "${_pkgfoldername}-${pkgver}" build -Dscripting=true
    ninja -C build
}

package() {
    DESTDIR="$pkgdir" meson install -C build
}
