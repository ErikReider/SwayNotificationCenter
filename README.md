# SwayNotificationCenter

A simple notification daemon with a gui built for Sway (potentially any wm with wlroots).

## Features

- A panel to view previous notifications
- Show album art for notifications like Spotify
- Do not disturb
- Click notification to execute default action
- Show alternative notification actions
- The same features as any other basic notification daemon

## Planned Features

- PLKGBUILD file for arch (and any others if requested 😃)
- Customization through a CSS file
- Slick animations 😎

## Install

Arch:

```zsh
makepkg -si
```

Other:

```zsh
meson build
ninja -C build
meson install -C build
```

## Run

To start the daemon (remember to kill any other notification daemon before running)

```zsh
./build/src/swaync
```

To toggle the panel

```zsh
./build/src/swaync-client
```

## Screenshots

![Screenshot of desktop notification](./assets/desktop.png)

![Screenshot of panel](./assets/panel.png)
