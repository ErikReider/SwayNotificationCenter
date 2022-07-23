# SwayNotificationCenter

[![Building](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/building.yml/badge.svg)](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/building.yml)

[![Linting](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/linting.yml/badge.svg)](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/linting.yml)

A simple notification daemon with a GTK gui for notifications and the control center

## Features

- Keyboard shortcuts
- Notification body markup with image support
- A panel to view previous notifications
- Show album art for notifications like Spotify
- Do not disturb
- Restores previous Do not disturb value after restart
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

Fedora:
The package is available on COPR:

```zsh
dnf copr enable erikreider/SwayNotificationCenter
dnf install SwayNotificationCenter
```

Gentoo:
An **unofficial** ebuild is available in [GURU](https://github.com/gentoo/guru)

```zsh
eselect repository enable guru
emaint sync -r guru
emerge --ask gui-apps/swaync
```

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

To reload css after changes

```zsh
./build/src/swaync-client -rs
```

## Control Center Shortcuts

- Up/Down: Navigate notifications
- Home: Navigate to the latest notification
- End: Navigate to the oldest notification
- Escape/Caps_Lock: Close notification panel
- Return: Execute default action or close notification if none
- Delete/BackSpace: Close notification
- Shift+C: Close all notifications
- Shift+D: Toggle Do Not Disturb
- Buttons 1-9: Execute alternative actions
- Left click button / actions: Activate notification action
- Right click notification: Close notification

## Configuring

The main config file is located in `/etc/xdg/swaync/config.json`. Copy it over
to your `.config/swaync/` folder to customize without needing root access.
See `swaync(1)` man page for more information

To reload the config, you'll need to run `swaync-client --reload-config`

The main CSS style file is located in `/etc/xdg/swaync/style.css`. Copy it over to your `~/.config/swaync/` folder to customize without needing root access.

## Scripting

Scripting rules and logic:

. <b>Only one</b> script can be fired per notification
. Each script requires `exec` and at least one of the other properties
. All listed properties must match the notification for the script to be ran
. If any of the propeties doesn't match, the script will be skipped
. If a notification doesn't include one of the properties, that property will
be skipped

More information can be found in the `swaync(5)` man page

Notification information can be printed into a terminal by running
`G_MESSAGES_DEBUG=all swaync` (when a notification appears).

Config properties:

```json
{
  "scripts": {
    "example-script": {
      "exec": "Your shell command or script here...",
      "app-name": "Notification app-name Regex",
      "summary": "Notification summary Regex",
      "body": "Notification body Regex",
      "urgency": "Low or Normal or Critical",
      "category": "Notification category Regex"
    }
  }
  other non scripting properties...
}
```

`config.json` example:

```json
{
  "scripts": {
    // This script will only run when Spotify sends a notification containing
    // that exact summary and body
    "example-script": {
      "exec": "~/.config/swaync/myRickRollScript.sh",
      "app-name": "Spotify"
      "summary": "Never Gonna Give You Up",
      "body": "Rick Astley - Whenever You Need Somebody"
    }
  }
  other non scripting properties...
}
```

### Disable scripting

To completely disable scripting, the project needs to be built like so:

```zsh
meson build -Dscripting=false
ninja -C build
meson install -C build
```

## Waybar Example

This example requires `NotoSansMono Nerd Font` to get the icons looking right

Waybar config

```json
  "custom/notification": {
    "tooltip": false,
    "format": "{icon}",
    "format-icons": {
      "notification": "<span foreground='red'><sup></sup></span>",
      "none": "",
      "dnd-notification": "<span foreground='red'><sup></sup></span>",
      "dnd-none": ""
    },
    "return-type": "json",
    "exec-if": "which swaync-client",
    "exec": "swaync-client -swb",
    "on-click": "swaync-client -t -sw",
    "on-click-right": "swaync-client -d -sw",
    "escape": true
  },
```

Waybar css file

```css
#custom-notification {
  font-family: "NotoSansMono Nerd Font";
}
```

Alternatively, the number of notifications can be shown by adding `{}` anywhere in the `format` field in the Waybar config

```json
  "custom/notification": {
    "format": "{} {icon}",
    ...
  },
```

## Screenshots

![Screenshot of desktop notification](./assets/desktop.png)

![Screenshot of panel](./assets/panel.png)

I wonder how this would look with some blur 🤔
