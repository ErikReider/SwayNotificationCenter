# SwayNotificationCenter

A simple notification daemon with a gui built for Sway (potentially any wm with wlroots).

## Features

- A panel to view previous notifications
- The same features as any other basic notification daemon

## Install

```zsh
meson build
ninja -C build
./build/src/sway-nc
```

## Run

To start the daemon

```zsh
./build/src/sway-nc
```

To toggle the panel

```zsh
./build/src/sway-nc-client
```

