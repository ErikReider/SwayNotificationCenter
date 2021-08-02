# SwayNotificationCenter

A simple notification daemon with a gui built for Sway (potentially any wm with wlroots).

## Features

- Keyboard shortcuts
- A panel to view previous notifications
- Show album art for notifications like Spotify
- Do not disturb
- Click notification to execute default action
- Show alternative notification actions
- Customization through a CSS file
- The same features as any other basic notification daemon

## Planned Features

- Slick animations 😎
- Other build scripts than a PKGBUILD (debian and/or RHEL systems)

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

## Notification Panel Shortcuts

- Up/Down: Navigate notifications
- Home: Navigate to the latest notification
- End: Navigate to the oldest notification
- Escape/Caps_Lock: Close notification panel
- Return: Execute default action or close notification if none
- Delete/BackSpace: Close notification
- C: Close all notifications
- D: Toggle Do Not Disturb
- Buttons 1-9: Execute alternative actions

## Configuring

To customize the appearance of the widgets, you'll need to create a `style.css`
file in `~/.config/swaync/style.css`.
<br>
At the time of writing, creating the file will override the default theme which
is located for most systems at `/etc/xdg/swaync/style.css`

## Screenshots

![Screenshot of desktop notification](./assets/desktop.png)

![Screenshot of panel](./assets/panel.png)

I wonder how this would look with some blur 🤔
