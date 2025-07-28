{
  description = "Flake for building SwayNotificationCenter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;

        swaync = pkgs.stdenv.mkDerivation {
          pname = "swaynotificationcenter";
          version = "unstable-${self.shortRev or "dirty"}";

          src = self;

          nativeBuildInputs = with pkgs; [
            meson
            ninja
            pkg-config
            vala
            gettext
            blueprint-compiler
            sassc
            scdoc
            cmake
            wayland-scanner
            git
            wrapGAppsHook3
            glib.bin
            python3
            libxml2
          ];

          buildInputs = [
            pkgs.glib.dev
            pkgs.gtk4.dev
            pkgs.libadwaita.dev
            pkgs.pantheon.granite7.dev
            pkgs.json-glib.dev
            pkgs.libnotify.dev
            pkgs.librsvg.dev
            pkgs.pango.dev
            pkgs.cairo.dev
            pkgs.gtk4-layer-shell.dev
            pkgs.libevdev
            pkgs.libinput
            pkgs.libpulseaudio
            pkgs.wayland.dev
            pkgs.wayland-protocols
          ];

          # Patch the shebang to the Nix python interpreter
          postPatch = ''
          patchShebangs build-aux/meson/postinstall.py
          '';

          # Configure with meson
          configurePhase = ''
            runHook preConfigure
            meson setup build \
              --prefix=$out \
              --libdir=lib \
              --datadir=share \
              -Dman-pages=true \
              -Dsystemd-service=false
            runHook postConfigure
          '';

          # Build with ninja
          buildPhase = ''
            runHook preBuild
            ninja -C build
            runHook postBuild
          '';

          # Install with ninja
          installPhase = ''
            runHook preInstall
            ninja -C build install
            runHook postInstall
          '';

          doCheck = false;

          meta = with lib; {
            description = "A GTK-based notification daemon for Sway";
            homepage = "https://github.com/ErikReider/SwayNotificationCenter";
            license = licenses.mit;
            platforms = platforms.linux;
            maintainers = with maintainers; [ ];
          };
        };
      in {
        packages.default = swaync;

        apps.default = flake-utils.lib.mkApp {
          drv = swaync;
          # If the binary name is known, set it explicitly:
          # program = "${swaync}/bin/swaync";
        };
      });
}
