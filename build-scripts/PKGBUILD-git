# vim: ft=sh
# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync-git
_pkgname=swaync
pkgver=r674.5fa4ce8
pkgrel=1
pkgdesc="A simple notification daemon with a GTK panel for checking previous notifications like other DEs"
url="https://github.com/ErikReider/SwayNotificationCenter"
arch=(
    'x86_64'
    'aarch64' # ARM v8 64-bit
    'armv7h'  # ARM v7 hardfloat
)
license=('GPL3')
depends=("gtk4" "gtk4-layer-shell>=1.0.4" "dbus" "glib2" "gobject-introspection" "libgee" "json-glib" "libpulse" "gvfs" "libnotify" "granite7" "blueprint-compiler" "libadwaita")
conflicts=("swaync" "swaync-client")
provides=("swaync" "swaync-client" "notification-daemon")
makedepends=("vala>=0.56" meson git scdoc sassc)
source=("$_pkgname::git+$url")
sha256sums=('SKIP')

pkgver() {
    cd $_pkgname
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

prepare() {
    cd $_pkgname
    git checkout main
}

build() {
    # Very important to be in the directory! Otherwise somehow breaks linking to the .ui files
    cd $_pkgname
    arch-meson build -Dscripting=true
    ninja -C build
}

package() {
    cd $_pkgname
    DESTDIR="$pkgdir/" ninja -C build install
    install -Dm644 "COPYING" -t "$pkgdir/usr/share/licenses/$pkgname"
    install -Dm644 "README.md" -t "$pkgdir/usr/share/doc/$pkgname"
}
