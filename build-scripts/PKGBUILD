# vim: ft=PKGBUILD
# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync
pkgver=0.10.1
pkgrel=1
pkgdesc="A simple notification daemon with a GTK panel for checking previous notifications like other DEs"
_pkgfoldername=SwayNotificationCenter
url="https://github.com/ErikReider/$_pkgfoldername"
arch=(
    'x86_64'
    'aarch64' # ARM v8 64-bit
    'armv7h'  # ARM v7 hardfloat
)
license=(GPL3)
depends=("gtk3" "gtk-layer-shell" "dbus" "glib2" "gobject-introspection" "libgee" "json-glib" "libhandy" "libpulse" "gvfs" "libnotify" "granite")
conflicts=("swaync" "swaync-client")
provides=("swaync" "swaync-client" "notification-daemon")
makedepends=("vala>=0.56" meson git scdoc sassc)
source=("${_pkgfoldername}-${pkgver}.tar.gz::${url}/archive/v${pkgver}.tar.gz")
sha256sums=('5586d8a679dde5e530cb8b6f0c86abdd0d5e41362fc1c4e56e2211edea0f7a13')

build() {
    arch-meson "${_pkgfoldername}-${pkgver}" build -Dscripting=true
    ninja -C build
}

package() {
    DESTDIR="$pkgdir/" ninja -C build install
    install -Dm644 "$_pkgfoldername-$pkgver/COPYING" -t "$pkgdir/usr/share/licenses/$pkgname"
    install -Dm644 "$_pkgfoldername-$pkgver/README.md" -t "$pkgdir/usr/share/doc/$pkgname"
}
