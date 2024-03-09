# vim: ft=PKGBUILD
# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync-git
_pkgname=swaync
pkgver=r517.4275fa3
pkgrel=1
pkgdesc="A simple notification daemon with a GTK panel for checking previous notifications like other DEs"
url="https://github.com/ErikReider/SwayNotificationCenter"
arch=(
    'x86_64'
    'aarch64' # ARM v8 64-bit
    'armv7h'  # ARM v7 hardfloat
)
license=('GPL3')
depends=("gtk3" "gtk-layer-shell" "dbus" "glib2" "gobject-introspection" "libgee" "json-glib" "libhandy" "libpulse" "gvfs" "libnotify" "granite")
conflicts=("swaync" "swaync-client")
provides=("swaync" "swaync-client" "notification-daemon")
makedepends=("vala>=0.56" meson git scdoc sassc)
source=("$_pkgname::git+$url")
sha256sums=('SKIP')

pkgver() {
    cd $_pkgname
    (
        set -o pipefail
        git describe --long 2>/dev/null | sed 's/\([^-]*-g\)/r\1/;s/-/./g' \
            || printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
    )
}

prepare() {
    cd $_pkgname
    git checkout main
}

build() {
    arch-meson $_pkgname build -Dscripting=true
    ninja -C build
}

package() {
    DESTDIR="$pkgdir/" ninja -C build install
    install -Dm644 "$_pkgname/COPYING" -t "$pkgdir/usr/share/licenses/$pkgname"
    install -Dm644 "$_pkgname/README.md" -t "$pkgdir/usr/share/doc/$pkgname"
}
