# SwayNotificationCenter

A simple notification daemon with a GTK gui for notifications and the control center

## Features

- Keyboard shortcuts
- Notification body markup with image support
- A panel to view previous notifications
- Show album art for notifications like Spotify
- Do not disturb
- Click notification to execute default action
- Show alternative notification actions
- Customization through a CSS file
- Trackpad/mouse gesture to close notification
- The same features as any other basic notification daemon
- Basic configuration through a JSON config file
- Hot-reload config through `swaync-client`

## Planned Features

- Slick animations 😎
- Other build scripts than a PKGBUILD (debian and/or RHEL systems)

## Install

Arch:
The package is available on the AUR:

- [swaync](https://aur.archlinux.org/packages/swaync/)
- [swaync-git](https://aur.archlinux.org/packages/swaync-git/)

Other:

```zsh
meson build
ninja -C build
meson install -C build
```

## Sway Usage

```ini
# Notification Daemon
exec swaync

# Toggle control center
bindsym $mod+Shift+n exec swaync-client -t -sw
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

To reload the config

```zsh
./build/src/swaync-client -R
```

## Control Center Shortcuts

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

The main config file is located in `/etc/xdg/swaync/config.json`. Copy it over
to your `.config/swaync/` folder to customize without needing root access.

To reload the config, you'll need to run `swaync-client --reload-config`

- `positionX`: `left`, `right` or `center`
- `positionY`: `top` or `bottom`
- `timeout`: uint (Any positive number). The notification timeout for notifications with normal priority
- `timeout-low`: uint (any positive number without decimals). The notification timeout for notifications with low priority
- `timeout-critical`: uint (any positive number without decimals, 0 to disable). The notification timeout for notifications with critical priority
- `keyboard-shortcuts`: `true` or `false`. If control center should use keyboard shortcuts
- `image-visibility`: `always`, `when-available` or `never`. Notification image visiblilty
- `transition-time`: uint (Any positive number, 0 to disable). The notification animation duration
- `notification-window-width`: uint (Any positive number). Width of the notification in pixels
- `hide-on-clear`: bool. Hides the control center after pressing "Clear All"
- `hide-on-action`: bool. Hides the control center when clicking on notification action
- `control-center-margin-top`: uint (Any positive number, 0 to disable). The margin (in pixels) at the top of the notification center
- `control-center-margin-bottom`: uint (Any positive number, 0 to disable). The margin (in pixels) at the bottom of the notification center
- `control-center-margin-right`: uint (Any positive number, 0 to disable). The margin (in pixels) at the right of the notification center
- `control-center-margin-left`: uint (Any positive number, 0 to disable). The margin (in pixels) at the left of the notification center

The main CSS style file is located in `/etc/xdg/swaync/style.css`. Copy it over to your `.config/swaync/` folder to customize without needing root access.

## Screenshots

![Screenshot of desktop notification](./assets/desktop.png)

![Screenshot of panel](./assets/panel.png)

I wonder how this would look with some blur 🤔
