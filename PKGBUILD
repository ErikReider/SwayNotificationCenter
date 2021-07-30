# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync-git
pkgver=0.1
pkgrel=1
pkgdesc="A simple notificaion daemon with a GTK panel for checking previous notifications like other DE's"
pkgfoldername=SwayNotificationCenter
url="https://github.com/ErikReider/$pkgfoldername"
arch=(x86_64)
license=(GPL)
depends=(gtk3 gtk-layer-shell dbus)
makedepends=(vala meson git)
source=("git+https://github.com/ErikReider/$pkgfoldername")
sha256sums=('SKIP')

pkgver() {
  cd $pkgfoldername
  printf "0.1.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
  arch-meson $pkgfoldername build
  ninja -C build
}

package() {
  DESTDIR="$pkgdir" meson install -C build
}
