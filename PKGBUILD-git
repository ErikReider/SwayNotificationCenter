# Maintainer: Erik Reider <erik.reider@protonmail.com>
pkgname=swaync-git
_ver="0.6.1"
pkgver="$_ver.r304.f0369e6"
pkgrel=1
pkgdesc="A simple notificaion daemon with a GTK panel for checking previous notifications like other DE's"
_pkgfoldername=SwayNotificationCenter
url="https://github.com/ErikReider/$_pkgfoldername"
arch=(x86_64)
license=(GPL)
depends=("gtk3>=3.22" "gtk-layer-shell>=0.1" "dbus" "glib2>=2.50" "gobject-introspection>=1.68" "libgee>=0.20" "json-glib>=1.0" "libhandy>=1.4.0")
conflicts=("swaync" "swaync-client")
provides=("swaync" "swaync-client")
makedepends=(vala meson git scdoc)
source=("git+$url")
sha256sums=('SKIP')

pkgver() {
  cd $_pkgfoldername
  printf "$_ver.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

prepare() {
  cd SwayNotificationCenter
  git checkout main
}

build() {
  arch-meson $_pkgfoldername build -Dscripting=true
  ninja -C build
}

package() {
  DESTDIR="$pkgdir" meson install -C build
}
