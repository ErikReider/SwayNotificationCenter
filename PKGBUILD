pkgname=swaync
pkgver=0.1
pkgrel=1
pkgdesc="A simple notificaion daemon with a GTK panel"
url="https://github.com/ErikReider/SwayNotificationCenter"
arch=(x86_64)
license=(GPL)
depends=(gtk3 gtk-layer-shell dbus)
makedepends=(vala meson git)
source=("git+https://github.com/ErikReider/SwayNotificationCenter")
sha256sums=('SKIP')

build() {
  # cd SwayNotificationCenter
  # pwd
  arch-meson SwayNotificationCenter build
  ninja -C build
}

package() {
  DESTDIR="$pkgdir" meson install -C build
}
