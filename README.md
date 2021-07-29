# SwayNotificationCenter

A simple notification daemon with a gui built for Sway (potentially any wm with wlroots).

## Features

- A panel to view previous notifications
- The same features as any other basic notification daemon

## Planned Features

- PLKGBUILD file for arch (and any others if requested 😃)
- Customization through a CSS file
- Click notification to execute default action
- Show alternative notification actions
- Slick animations 😎

## Install

```zsh
meson build
ninja -C build
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

## Screenshots

![Screenshot of desktop notification](./assets/desktop.png)

![Screenshot of panel](./assets/panel.png)
