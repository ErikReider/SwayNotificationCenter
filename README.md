# SwayNotificationCenter

A simple notification daemon with a gui built for Sway (potentially any wm with wlroots).

## Features

- A panel to view previous notifications
- Show album art for notifications like Spotify
- Do not disturb
- Click notification to execute default action
- Show alternative notification actions
- Customization through a CSS file
- The same features as any other basic notification daemon

## Planned Features

- PLKGBUILD file for arch (and any others if requested 😃)

- Slick animations 😎

## Install

Arch:
The package is available on the [AUR](https://aur.archlinux.org/packages/swaync-git/)

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
./build/src/swaync-client -t
```

## Configuring

To customize the appearance of the widgets, you'll need to create a `style.css` file in `~/.config/swaync/style.css`.
<br>At the time of writing, creating the file will override the default theme which is located for most systems at `/etc/xdg/swaync/style.css`

## Screenshots

![Screenshot of desktop notification](./assets/desktop.png)

![Screenshot of panel](./assets/panel.png)
