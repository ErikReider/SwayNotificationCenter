#!/bin/bash

rm -rf ./build/

dnf install -y gtk-layer-shell-devel \
    libhandy-devel \
    vala \
    json-glib-devel \
    meson \
    cmake 

meson build
ninja -C build
meson install -C build
