# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync-git
pkgver=0.1.r82.c9ab1de
pkgrel=1
pkgdesc="A simple notificaion daemon with a GTK panel for checking previous notifications like other DE's"
_pkgfoldername=SwayNotificationCenter
url="https://github.com/ErikReider/$_pkgfoldername"
arch=(x86_64)
license=(GPL)
depends=("gtk3>=3.22" "gtk-layer-shell>=0.1" "dbus" "glib2>=2.50" "vala-dbus-binding-tool-git>=1.0" "gobject-introspection>=1.68" "libgee>=0.20")
makedepends=(vala meson git)
source=("git+$url")
sha256sums=('SKIP')

pkgver() {
  cd $_pkgfoldername
  printf "0.1.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
  arch-meson $_pkgfoldername build
  ninja -C build
}

package() {
  DESTDIR="$pkgdir" meson install -C build
}
