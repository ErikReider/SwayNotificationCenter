# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync-git
_pkgname=swaync
pkgver=v0.6.3.r1.g2b8506a
pkgrel=1
pkgdesc="A simple notificaion daemon with a GTK panel for checking previous notifications like other DEs"
url="https://github.com/ErikReider/SwayNotificationCenter"
arch=(
    'x86_64'
    'aarch64' # ARM v8 64-bit
    'armv7h'  # ARM v7 hardfloat
)
license=('GPL3')
depends=("gtk3>=3.22" "gtk-layer-shell>=0.1" "dbus" "glib2>=2.50" "gobject-introspection>=1.68" "libgee>=0.20" "json-glib>=1.0" "libhandy>=1.4.0")
conflicts=("swaync" "swaync-client")
provides=("swaync" "swaync-client")
makedepends=(vala meson git scdoc)
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
    DESTDIR="$pkgdir" meson install -C build
}
