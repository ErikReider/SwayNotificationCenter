# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync
pkgver=0.6.2
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
depends=("gtk3>=3.22" "gtk-layer-shell>=0.1" "dbus" "glib2>=2.50" "gobject-introspection>=1.68" "libgee>=0.20" "json-glib>=1.0" "libhandy>=1.4.0")
conflicts=("swaync" "swaync-client")
provides=("swaync" "swaync-client")
makedepends=(vala meson git scdoc)
source=("${_pkgfoldername}-${pkgver}.tar.gz::${url}/archive/v${pkgver}.tar.gz")
sha256sums=('08cb3e2a0528719973745bbddda9701039c5cda0a48c98f49c5b30b4a0af68d9')

build() {
    arch-meson "${_pkgfoldername}-${pkgver}" build -Dscripting=true
    ninja -C build
}

package() {
    DESTDIR="$pkgdir" meson install -C build
}
