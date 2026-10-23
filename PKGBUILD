# Maintainer: Renato <renato@omarchy.local>
pkgname=focus-browser-git
_pkgname=focus
pkgver=0.1.0
pkgrel=4
pkgdesc="Navegador web minimalista, veloz e focado para Omarchy OS"
arch=('x86_64')
url="https://github.com/rluizti/Focus"
license=('MIT')
depends=('qt6-base' 'qt6-declarative' 'qt6-webengine' 'qt6-svg' 'hicolor-icon-theme')
makedepends=('cargo' 'cmake' 'clang')
provides=('focus')
conflicts=('focus')
options=('!lto')

build() {
    cd "$startdir"
    cargo build --release --locked
}

package() {
    cd "$startdir"

    # Binário
    install -Dm755 "target/release/focus" "$pkgdir/usr/bin/focus"

    # UI QML & Assets
    mkdir -p "$pkgdir/usr/share/focus"
    cp -r ui "$pkgdir/usr/share/focus/"
    cp -r assets "$pkgdir/usr/share/focus/"

    # Desktop entry & Ícones
    install -Dm644 "focus.desktop" "$pkgdir/usr/share/applications/focus.desktop"
    install -Dm644 "assets/focus.svg" "$pkgdir/usr/share/icons/hicolor/scalable/apps/focus.svg"
    install -Dm644 "assets/focus.png" "$pkgdir/usr/share/icons/hicolor/512x512/apps/focus.png"
    install -Dm644 "assets/focus_256.png" "$pkgdir/usr/share/icons/hicolor/256x256/apps/focus.png"
    install -Dm644 "assets/focus_128.png" "$pkgdir/usr/share/icons/hicolor/128x128/apps/focus.png"
}
